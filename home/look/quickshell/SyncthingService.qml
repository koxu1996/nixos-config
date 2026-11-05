// SyncthingService.qml: data for Syncthing.qml, from the local Syncthing REST API.
//
// - API key and GUI address: Syncthing's config.xml (services.syncthing.configDir in
//   modules/base.nix), re-read when it changes. Requests are plain XMLHttpRequests.
// - Live: a long-poll on /rest/events (60 s server timeout) refreshes as soon as a
//   folder changes state, a device (dis)connects, completion moves or the config is saved.
// - Refresh: config (devices, folders), connections (+ transfer rates), folder status,
//   completion of each connected device, last seen, errors, pending devices/folders.
//   Every 30 s as a fallback, every 2 s while the panel is open.
// - Conflicts: `find` for *.sync-conflict-* files in the folders, at most every 15 s.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: service

    // ---- Configuration -------------------------------------------------------------------
    property string configPath: `${Quickshell.env("HOME")}/.local/state/syncthing/config.xml`
    property bool panelOpen: false // set by Syncthing.qml: fast refresh for transfer rates

    // ---- Connection ----------------------------------------------------------------------
    property string apiKey: ""
    property string baseUrl: "http://127.0.0.1:8384"
    property bool reachable: false

    FileView {
        path: service.configPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const t = text();
            service.apiKey = (t.match(/<apikey>([^<]+)<\/apikey>/) ?? [])[1] ?? "";
            const gui = (t.match(/<gui\b[^>]*>([\s\S]*?)<\/gui>/) ?? [])[1] ?? "";
            const addr = (gui.match(/<address>([^<]+)<\/address>/) ?? [])[1] ?? "127.0.0.1:8384";
            service.baseUrl = `http://${addr.replace(/^0\.0\.0\.0:/, "127.0.0.1:")}`;
            service.refresh();
            service.restartEvents();
        }
    }

    // onDone(data, ok); data is parsed JSON (null for an empty body).
    function request(method, path, onDone) {
        if (apiKey === "") return null;
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            let data = null;
            if (x.status === 200) { try { data = x.responseText ? JSON.parse(x.responseText) : null; } catch (e) {} }
            if (onDone) onDone(data, x.status === 200);
        };
        x.open(method, `${baseUrl}/rest/${path}`);
        x.setRequestHeader("X-API-Key", apiKey);
        x.send();
        return x;
    }

    // ---- Raw state -----------------------------------------------------------------------
    property string myId: ""
    property var devices: []        // config/devices
    property var folders: []        // config/folders
    property var connections: ({})  // device ID -> connection
    property var folderStatus: ({}) // folder ID -> db/status
    property var completion: ({})   // device ID -> db/completion (all folders shared with it)
    property var deviceStats: ({})  // device ID -> { lastSeen }
    property var errors: []         // [{ when, message }]
    property var pendingDevices: ({})
    property var pendingFolders: ({})
    property var conflicts: []      // paths of *.sync-conflict-* files
    property real inRate: 0         // bytes/s, all devices
    property real outRate: 0

    property real prevAt: 0
    property real prevIn: 0
    property real prevOut: 0

    function refresh() {
        request("GET", "system/status", (d, ok) => {
            service.reachable = ok;
            if (ok) service.myId = d.myID;
        });
        request("GET", "config/devices", (d, ok) => { if (ok) service.devices = d; });
        request("GET", "config/folders", (d, ok) => {
            if (!ok) return;
            service.folders = d;
            for (const f of d) {
                request("GET", `db/status?folder=${encodeURIComponent(f.id)}`, (s, sok) => {
                    if (!sok) return;
                    const next = Object.assign({}, service.folderStatus);
                    next[f.id] = s;
                    service.folderStatus = next;
                });
            }
            service.findConflicts();
        });
        request("GET", "system/connections", (d, ok) => {
            if (!ok) return;
            const at = Date.parse(d.total.at);
            if (service.prevAt > 0 && at > service.prevAt) {
                service.inRate = Math.max(0, (d.total.inBytesTotal - service.prevIn) * 1000 / (at - service.prevAt));
                service.outRate = Math.max(0, (d.total.outBytesTotal - service.prevOut) * 1000 / (at - service.prevAt));
            }
            service.prevAt = at; service.prevIn = d.total.inBytesTotal; service.prevOut = d.total.outBytesTotal;
            service.connections = d.connections;
            for (const id in d.connections) {
                if (!d.connections[id].connected) continue;
                request("GET", `db/completion?device=${id}`, (c, cok) => {
                    if (!cok) return;
                    const next = Object.assign({}, service.completion);
                    next[id] = c;
                    service.completion = next;
                });
            }
        });
        request("GET", "stats/device", (d, ok) => { if (ok) service.deviceStats = d; });
        request("GET", "system/error", (d, ok) => { if (ok) service.errors = d.errors ?? []; });
        request("GET", "cluster/pending/devices", (d, ok) => { if (ok) service.pendingDevices = d ?? {}; });
        request("GET", "cluster/pending/folders", (d, ok) => { if (ok) service.pendingFolders = d ?? {}; });
    }

    Timer {
        interval: service.panelOpen ? 2000 : 30000
        running: service.apiKey !== ""
        repeat: true
        onTriggered: service.refresh()
    }

    Timer { id: refreshSoon; interval: 300; onTriggered: service.refresh() }

    // ---- Events (long-poll) --------------------------------------------------------------
    readonly property string eventTypes: "StateChanged,FolderSummary,FolderCompletion,FolderErrors,FolderPaused,"
        + "FolderResumed,DeviceConnected,DeviceDisconnected,DevicePaused,DeviceResumed,ConfigSaved,"
        + "PendingDevicesChanged,PendingFoldersChanged"
    property int lastEventId: 0
    property var eventRequest: null

    function restartEvents() {
        if (eventRequest) eventRequest.abort();
        eventRequest = null;
        lastEventId = 0;
        pollEvents();
    }

    // First call: the newest event's ID (no wait). Then: wait for events after it.
    function pollEvents() {
        const first = lastEventId === 0;
        const path = first ? "events?since=0&limit=1&timeout=0"
                           : `events?since=${lastEventId}&timeout=60&events=${eventTypes}`;
        const req = request("GET", path, (d, ok) => {
            if (req !== service.eventRequest) return; // superseded
            service.eventRequest = null;
            eventWatchdog.stop();
            if (!ok || !Array.isArray(d)) {
                // Syncthing stopped or restarted (event IDs start over): resync after a pause.
                service.reachable = false;
                service.lastEventId = 0;
                eventRetry.restart();
                return;
            }
            if (d.length > 0) service.lastEventId = d[d.length - 1].id;
            if (!first && d.length > 0) refreshSoon.restart();
            if (first && service.lastEventId === 0) { eventRetry.restart(); return; }
            service.pollEvents();
        });
        eventRequest = req;
        if (req) eventWatchdog.restart();
    }

    Timer { id: eventRetry; interval: 5000; onTriggered: { service.refresh(); service.pollEvents(); } }

    // A request the server should have answered by now (60 s timeout) is stuck: start over.
    Timer { id: eventWatchdog; interval: 75000; onTriggered: service.restartEvents() }

    // ---- Conflicts -------------------------------------------------------------------------
    property real conflictsReadAt: 0

    function findConflicts() {
        if (conflictFinder.running || Date.now() - conflictsReadAt < 15000) return;
        const paths = folders.map(f => f.path.replace(/^~/, Quickshell.env("HOME")));
        if (paths.length === 0) return;
        conflictsReadAt = Date.now();
        conflictFinder.command = ["find", ...paths, "-name", ".stversions", "-prune", "-o",
                                  "-name", "*.sync-conflict-*", "-print"];
        conflictFinder.running = true;
    }

    Process {
        id: conflictFinder
        stdout: StdioCollector {
            onStreamFinished: service.conflicts = text.split("\n").filter(l => l !== "")
        }
    }

    // ---- Actions ---------------------------------------------------------------------------
    function rescanAll() { request("POST", "db/scan", () => refreshSoon.restart()); }
    function pauseAll() { request("POST", "system/pause", () => refreshSoon.restart()); }
    function resumeAll() { request("POST", "system/resume", () => refreshSoon.restart()); }
    function openWebUi() { Qt.openUrlExternally(baseUrl); }
    function openFolder(path) { Qt.openUrlExternally(`file://${path}`); }

    // ---- Derived ---------------------------------------------------------------------------
    function nameOf(id) { return devices.find(d => d.deviceID === id)?.name || id.slice(0, 7); }

    readonly property string myName: myId === "" ? "" : nameOf(myId)

    // Remote devices: [{ id, name, connected, paused, link, lastSeen, completion }]
    readonly property var deviceRows: devices.filter(d => d.deviceID !== myId).map(d => {
        const c = connections[d.deviceID] ?? {};
        const comp = completion[d.deviceID];
        // A device that shares nothing reports 0% with nothing to send: count only real needs.
        const behind = comp && (comp.needBytes > 0 || comp.needItems > 0 || comp.needDeletes > 0);
        const proto = (c.type ?? "").split("-")[0].toUpperCase();
        return {
            id: d.deviceID,
            name: d.name || d.deviceID.slice(0, 7),
            connected: c.connected === true,
            paused: c.paused === true || d.paused === true,
            link: c.connected ? `${(c.type ?? "").startsWith("relay") ? "Relay" : c.isLocal ? "LAN" : "WAN"} · ${proto}` : "",
            lastSeen: deviceStats[d.deviceID]?.lastSeen ?? "",
            completion: c.connected && comp ? (behind ? Math.min(comp.completion, 99.9) : 100) : -1,
            needBytes: c.connected && comp ? comp.needBytes : 0
        };
    })

    // Folders: [{ id, label, path, state, paused, globalBytes, globalFiles, needBytes, failed, sharedWith }]
    readonly property var folderRows: folders.map(f => {
        const s = folderStatus[f.id] ?? {};
        return {
            id: f.id,
            label: f.label || f.id,
            path: f.path,
            state: f.paused ? "paused" : (s.state ?? "unknown"),
            paused: f.paused === true,
            globalBytes: s.globalBytes ?? 0,
            globalFiles: s.globalFiles ?? 0,
            needBytes: s.needBytes ?? 0,
            failed: s.pullErrors ?? 0,
            error: s.error ?? "",
            sharedWith: f.devices.map(d => d.deviceID).filter(id => id !== myId).map(id => nameOf(id))
        };
    })

    readonly property int peersTotal: deviceRows.length
    readonly property int peersOnline: deviceRows.filter(d => d.connected).length
    readonly property bool allPaused: peersTotal > 0 && deviceRows.every(d => d.paused)
    readonly property var unshared: folderRows.filter(f => f.sharedWith.length === 0)
    readonly property int pendingCount: Object.keys(pendingDevices).length + Object.keys(pendingFolders).length
    readonly property int failedCount: folderRows.reduce((n, f) => n + f.failed + (f.state === "error" ? 1 : 0), 0)

    // Pulling (this machine downloads) or pushing (a connected device is behind).
    readonly property bool pulling: folderRows.some(f => f.state.startsWith("sync"))
    readonly property bool pushing: deviceRows.some(d => d.connected && d.completion >= 0 && d.completion < 100)
    readonly property real totalBytes: folderRows.reduce((n, f) => n + f.globalBytes, 0)
    readonly property real needBytes: folderRows.reduce((n, f) => n + f.needBytes, 0)
    readonly property int localCompletion: totalBytes > 0 ? Math.floor(100 * (totalBytes - needBytes) / totalBytes) : 100

    // offline | error | syncing | paused | attention | alone | ok
    readonly property string status: !reachable ? "offline"
        : errors.length > 0 || failedCount > 0 ? "error"
        : pulling || pushing ? "syncing"
        : allPaused ? "paused"
        : unshared.length > 0 || conflicts.length > 0 || pendingCount > 0 ? "attention"
        : peersOnline === 0 ? "alone"
        : "ok"

    // "alone" (no other device online) is green like "ok": nothing is wrong, the panel
    // says who's offline. Grey only when Syncthing itself is off or paused.
    readonly property color statusColor: ({
        offline: Theme.textDisabled, error: Theme.error, syncing: Theme.accent, paused: Theme.textDisabled,
        attention: Theme.warning, alone: Theme.accent, ok: Theme.accent
    })[status]

    readonly property string headline: {
        switch (status) {
        case "offline": return "Syncthing isn't running";
        case "error": return errors.length > 0 ? plural(errors.length, "error") : plural(failedCount, "file") + " failed";
        case "syncing": return pulling ? `Syncing · ${localCompletion}%` : "Sending changes";
        case "paused": return "Paused";
        case "attention":
            if (unshared.length > 0) return unshared.length === 1 ? `“${unshared[0].label}” isn't shared` : `${unshared.length} folders aren't shared`;
            if (conflicts.length > 0) return plural(conflicts.length, "conflict");
            return plural(pendingCount, "pending request");
        case "alone": return "No devices online";
        default: return "Up to date";
        }
    }

    readonly property string subline: !reachable ? baseUrl
        : `${myName} · ${peersOnline} of ${peersTotal} ${peersTotal === 1 ? "device" : "devices"} online`

    // ---- Formatting --------------------------------------------------------------------------
    function plural(n, word) { return `${n} ${word}${n === 1 ? "" : "s"}`; }

    // 126614 -> "124 KiB"
    function bytes(n) {
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let i = 0;
        while (n >= 1024 && i < units.length - 1) { n /= 1024; i++; }
        return `${n >= 100 || i === 0 ? Math.round(n) : n.toFixed(1)} ${units[i]}`;
    }

    // ISO time -> "5 min ago"; "never" for Syncthing's zero time.
    function ago(iso) {
        const t = Date.parse(iso);
        if (!(t > Date.parse("2000-01-01"))) return "never";
        const s = (Date.now() - t) / 1000;
        if (s < 60) return "just now";
        if (s < 3600) return `${Math.floor(s / 60)} min ago`;
        if (s < 86400) return `${Math.floor(s / 3600)} h ago`;
        return `${Math.floor(s / 86400)} d ago`;
    }

    // Folder state as shown: "idle" -> "Up to date".
    function stateLabel(f) {
        if (f.paused) return "Paused";
        if (f.state === "error") return "Error";
        if (f.failed > 0) return `${f.failed} failed`;
        if (f.state === "idle") return "Up to date";
        if (f.state.startsWith("sync")) return "Syncing";
        if (f.state.startsWith("scan")) return "Scanning";
        return f.state.charAt(0).toUpperCase() + f.state.slice(1);
    }
}
