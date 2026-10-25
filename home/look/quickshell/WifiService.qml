// WifiService.qml: Wi-Fi state and actions for Wifi.qml (wlan0), on iwd.
// iwd is both the Wi-Fi daemon and the DHCP client (no NetworkManager, so
// Quickshell.Networking reports nothing). State comes from iwd's D-Bus API through
// `busctl --json=short` (parsed in iwd.js), plus `ip` and `rfkill`, polled every 3 s
// (2 s while the popover is open, 0.5 s while connecting). Actions are D-Bus calls on the
// station / network / known-network objects; a new password-protected network is joined
// with `iwctl --passphrase`. andrew may talk to iwd as a member of `wheel` (iwd's D-Bus
// policy), so nothing runs as root.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "iwd.js" as Iwd

Singleton {
    id: service

    readonly property string iface: "wlan0"
    readonly property int historyLength: 60

    // Set by Wifi.qml while its popover is open: faster polling, scanning, rate history.
    property bool panelOpen: false

    // ---- Radio ------------------------------------------------------------------------
    property bool radioOn: true
    property bool hardBlocked: false

    function setRadio(on) {
        if (hardBlocked) return;
        radioOn = on; // optimistic; the next poll confirms
        failure = "";
        run(["rfkill", on ? "unblock" : "block", "wlan"]);
    }

    // ---- Link state (iwd Station + StationDiagnostic) ---------------------------------------
    property string stationState: ""  // connected, connecting, disconnected, disconnecting, roaming
    property string stationPath: ""   // D-Bus object of wlan0's station ("" while it is down)
    property string ssid: ""
    property string bssid: ""
    property int freq: 0              // MHz
    property string width: ""         // not reported by iwd
    property int wifiGeneration: 0    // 4, 5, 6, … (0 = unknown)
    property string security: ""      // "WPA2", "WPA3", "Open"
    property int rssi: 0              // dBm
    property int linkSpeed: 0         // Mbit/s
    property string ipv4: ""
    property string ipv6: ""
    property string gateway: ""
    property string dns: ""
    property string onlineState: ""
    property string model: ""         // "BCM4387"

    readonly property bool connected: radioOn && stationState === "connected" && ipv4 !== ""
    readonly property string band: bandOf(freq)
    readonly property int channel: channelOf(freq)
    readonly property string quality: rssi >= -50 ? "excellent" : rssi >= -60 ? "good" : rssi >= -70 ? "fair" : "weak"
    readonly property int level: levelOf(rssi)

    // ---- Saved (known) networks ---------------------------------------------------------
    // "profile" is the saved network in use (its SSID), "profiles" all saved SSIDs: the names
    // Wifi.qml already uses.
    property string profile: ""
    property var profiles: []
    property var knownPaths: ({})   // ssid -> KnownNetwork object
    property var networkPaths: ({})  // ssid -> Network object (in range)
    property string lastSsid: ""    // last network we were connected to
    property string lastProfile: ""

    onConnectedChanged: if (connected) { lastSsid = ssid; lastProfile = profile; }

    function profileFor(name) { return name; }
    function isSaved(name) { return profiles.includes(name); }

    // ---- Connection progress -------------------------------------------------------------
    // While an action runs: { action: "switch" | "join" | "forget", ssid, profile }.
    property var pending: null
    property string failure: "" // short message for the current-network card

    readonly property bool helperBusy: actionProc.running
    readonly property bool connecting: radioOn && (
        (pending !== null && pending.action !== "forget")
        || ["connecting", "roaming"].includes(stationState)
        || (stationState === "connected" && ipv4 === ""))
    // 0 = associating / checking the password, 2 = getting an address.
    readonly property int connectStep: stationState === "connected" ? 2 : 0
    readonly property string connectingSsid: pending?.ssid || ssid || lastSsid

    function iwd(path, iface, method) {
        return ["busctl", "call", "net.connman.iwd", path, "net.connman.iwd." + iface, method];
    }

    function act(pendingValue, command) {
        if (helperBusy) return;
        failure = "";
        pending = pendingValue;
        actionProc.command = command;
        actionProc.running = true;
    }

    // A saved network in range: connect with its stored credentials.
    function switchTo(name) {
        const path = networkPaths[name];
        if (!path) { failure = "Network not in range"; return; }
        act({ action: "switch", ssid: name, profile: name }, iwd(path, "Network", "Connect"));
    }

    // A new network: open ones through D-Bus, others with the password through iwctl (the
    // only way without registering a D-Bus agent).
    function join(name, password) {
        const path = networkPaths[name];
        if (!password && path) act({ action: "join", ssid: name, profile: name }, iwd(path, "Network", "Connect"));
        else act({ action: "join", ssid: name, profile: name },
                 ["iwctl", "--passphrase", password ?? "", "station", iface, "connect", name]);
    }

    function forget(name) {
        const path = knownPaths[name];
        if (!path) return;
        act({ action: "forget", ssid: "", profile: name }, iwd(path, "KnownNetwork", "Forget"));
    }

    function disconnect() {
        failure = "";
        if (stationPath) run(iwd(stationPath, "Station", "Disconnect"));
    }

    // Reconnect to the last saved network, if it is in range.
    function reconnect() {
        failure = "";
        if (lastProfile && networkPaths[lastProfile]) switchTo(lastProfile);
    }

    Process {
        id: actionProc

        stdout: StdioCollector {}
        stderr: StdioCollector { id: actionStderr }

        onExited: (code, status) => {
            const action = service.pending?.action;
            if (code !== 0 && service.failure === "") {
                const last = actionStderr.text.trim().split("\n").pop()
                    .replace(/^Call failed: /, "").replace(/^net\.connman\.iwd\./, "");
                service.failure = /Invalid ?Format|passphrase|Invalid key/i.test(last) ? "Wrong password"
                    : /NotFound|not found/i.test(last) ? "Network not found"
                    : /Timeout|timed out/i.test(last) ? "Timed out"
                    : /Access ?Denied|not allowed/i.test(last) ? "Not authorized"
                    : last ? last.charAt(0).toUpperCase() + last.slice(1)
                    : action === "forget" ? "Couldn't forget the network" : "Couldn't connect";
            }
            service.pending = null;
            service.refresh();
        }
    }

    // ---- Polling ---------------------------------------------------------------------
    function refresh() { if (!poller.running) poller.running = true; }

    Timer {
        interval: service.connecting || service.scanning ? 500 : service.panelOpen ? 2000 : 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: service.refresh()
    }

    Process {
        id: poller
        command: ["sh", "-c",
            "i=" + service.iface + "; "
            + "echo @rfkill; rfkill -J list wlan 2>/dev/null; "
            + "echo @addr; ip -j addr show dev $i 2>/dev/null; echo; "
            + "echo @route; ip -j route show default dev $i 2>/dev/null; echo; "
            + "echo @objects; busctl --json=short call net.connman.iwd / org.freedesktop.DBus.ObjectManager GetManagedObjects 2>/dev/null; echo"]
        stdout: StdioCollector { onStreamFinished: service.parsePoll(text) }
    }

    // Signal per network and link details need the station's object path, so they follow.
    Process {
        id: details
        property string path: ""
        command: ["sh", "-c",
            "echo @ordered; busctl --json=short call net.connman.iwd \"$1\" net.connman.iwd.Station GetOrderedNetworks 2>/dev/null; echo; "
            + "echo @diag; busctl --json=short call net.connman.iwd \"$1\" net.connman.iwd.StationDiagnostic GetDiagnostics 2>/dev/null; echo",
            "sh", path]
        stdout: StdioCollector { onStreamFinished: service.parseDetails(text) }
    }

    function sections(text) {
        const out = {};
        let key = "";
        for (const line of text.split("\n")) {
            if (/^@\w+$/.test(line)) { key = line.slice(1); out[key] = []; }
            else if (key) out[key].push(line);
        }
        return out;
    }

    function json(lines) {
        try { return JSON.parse((lines ?? []).join("\n").trim() || "null"); } catch (e) { return null; }
    }

    property var objects: Iwd.parseManagedObjects(null)

    function parsePoll(text) {
        const s = sections(text);

        const rf = (json(s.rfkill)?.rfkilldevices ?? []).filter(d => d.type === "wlan");
        if (rf.length) {
            hardBlocked = rf.some(d => d.hard === "blocked");
            radioOn = !hardBlocked && !rf.some(d => d.soft === "blocked");
        }

        const objs = Iwd.parseManagedObjects(json(s.objects));
        objects = objs;
        stationPath = objs.station.path;
        stationState = objs.station.state;
        ssid = objs.station.connectedSsid;
        if (objs.model) model = objs.model;
        if (scanning && !objs.station.scanning && Date.now() - scanStarted > 1500) scanning = false;

        const known = {}, inRange = {};
        for (const k of objs.known) known[k.ssid] = k.path;
        for (const path of Object.keys(objs.networks)) inRange[objs.networks[path].ssid] = path;
        knownPaths = known;
        networkPaths = inRange;
        const names = objs.known.map(k => k.ssid).sort();
        if (names.join("\n") !== profiles.join("\n")) profiles = names;
        profile = known[ssid] ? ssid : "";

        const up = stationState === "connected";
        const addr = (json(s.addr) ?? [])[0]?.addr_info ?? [];
        ipv4 = up ? (addr.find(a => a.family === "inet")?.local ?? "") : "";
        ipv6 = up ? (addr.find(a => a.family === "inet6" && a.scope === "global")?.local ?? "") : "";
        gateway = up ? ((json(s.route) ?? [])[0]?.gateway ?? "") : "";
        onlineState = stationState;

        if (stationPath && !details.running) {
            details.path = stationPath;
            details.running = true;
        }
        if (panelOpen) resolvConf.reload();
    }

    property var signals: ({})

    function parseDetails(text) {
        const s = sections(text);
        signals = Iwd.parseOrdered(json(s.ordered));
        const d = Iwd.parseDiagnostics(json(s.diag));
        if (stationState === "connected") {
            bssid = d.bssid;
            freq = d.freq;
            rssi = d.rssi || rssi;
            linkSpeed = d.linkSpeed;
            wifiGeneration = d.wifiGeneration;
            security = d.security;
        } else {
            bssid = ""; freq = 0; linkSpeed = 0; wifiGeneration = 0; security = "";
        }
    }

    FileView {
        id: resolvConf
        path: "/etc/resolv.conf"
        onLoaded: {
            const servers = [];
            for (const line of text().split("\n")) {
                const m = /^nameserver\s+(\S+)/.exec(line);
                if (m) servers.push(m[1]);
            }
            service.dns = servers.join(", ");
        }
    }

    // ---- Scanning -----------------------------------------------------------------------
    property bool scanning: false
    property real scanStarted: 0

    // Saved first, then by signal; the connected network is left out (iwd.js).
    readonly property var networks: Iwd.networkList(objects, signals)
        .map(n => Object.assign({}, n, { profile: n.ssid }))

    function scan() {
        if (scanning || !radioOn || !stationPath) return;
        scanning = true;
        scanStarted = Date.now();
        run(iwd(stationPath, "Station", "Scan"));
    }

    // Every 15 s while the popover stays open; never while it is closed.
    Timer {
        interval: 15000
        repeat: true
        running: service.panelOpen && service.radioOn
        onTriggered: service.scan()
    }

    onPanelOpenChanged: {
        if (panelOpen) { scan(); refresh(); }
        else { rxHistory = []; txHistory = []; }
    }

    // ---- Traffic --------------------------------------------------------------------------
    property real rxRate: 0 // bytes/s
    property real txRate: 0
    property var rxHistory: []
    property var txHistory: []
    property real lastRx: -1
    property real lastTx: -1
    property real lastSample: 0

    Timer {
        interval: service.panelOpen ? 1000 : 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            rxFile.reload();
            txFile.reload();
            const rx = parseFloat(rxFile.text()), tx = parseFloat(txFile.text()), now = Date.now();
            if (!Number.isFinite(rx) || !Number.isFinite(tx)) return;
            if (service.lastRx >= 0 && now > service.lastSample) {
                const dt = (now - service.lastSample) / 1000;
                service.rxRate = Math.max(0, (rx - service.lastRx) / dt);
                service.txRate = Math.max(0, (tx - service.lastTx) / dt);
                if (service.panelOpen) {
                    service.rxHistory = service.pushed(service.rxHistory, service.rxRate);
                    service.txHistory = service.pushed(service.txHistory, service.txRate);
                }
            }
            service.lastRx = rx;
            service.lastTx = tx;
            service.lastSample = now;
        }
    }

    FileView { id: rxFile; path: `/sys/class/net/${service.iface}/statistics/rx_bytes`; blockLoading: true }
    FileView { id: txFile; path: `/sys/class/net/${service.iface}/statistics/tx_bytes`; blockLoading: true }

    function pushed(list, value) {
        const next = list.length >= historyLength ? list.slice(list.length - historyLength + 1) : list.slice();
        next.push(value);
        return next;
    }

    // ---- Helpers --------------------------------------------------------------------------
    // Fire-and-forget command, then refresh.
    function run(cmd) {
        const proc = runner.createObject(service, { command: cmd });
        proc.running = true;
    }

    Component {
        id: runner
        Process {
            onExited: { service.refresh(); destroy(); }
        }
    }

    function bandOf(f) {
        return f >= 5925 ? "6" : f >= 4900 ? "5" : f >= 2400 ? "2.4" : "";
    }

    function channelOf(f) {
        if (f === 2484) return 14;
        if (f >= 2412 && f < 2484) return (f - 2407) / 5;
        if (f >= 5925) return (f - 5950) / 5;
        if (f >= 4900) return (f - 5000) / 5;
        return 0;
    }

    function levelOf(dbm) {
        return dbm >= -55 ? 4 : dbm >= -65 ? 3 : dbm >= -75 ? 2 : 1;
    }

    // Bytes/s -> "512 B/s", "84 KB/s", "1.4 MB/s".
    function formatRate(b) {
        if (b < 1024) return `${Math.round(b)} B/s`;
        if (b < 1024 * 1024) return `${Math.round(b / 1024)} KB/s`;
        return `${(b / 1048576).toFixed(1)} MB/s`;
    }
}
