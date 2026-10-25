// TailscaleService.qml: Tailscale state for TailscaleChip.qml, from `tailscale status --json`:
// every 30 s, every 3 s while the panel is open, and right after a change.
// On/off through the CLI as tailscale's operator (andrew, services.tailscale.extraSetFlags in
// modules/base.nix): `up` on a logged-out node prints a login URL and waits, so the URL is
// opened in the browser and the command gives up after 120 s.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: service

    property bool panelOpen: false

    // ---- State -----------------------------------------------------------------------------
    property string backendState: "" // Running, Stopped, NeedsLogin, Starting, … ("" = no tailscaled)
    property string ip: ""           // this machine's IPv4 on the tailnet
    property string hostName: ""
    property string dnsName: ""      // nixair.pony-balance.ts.net
    property string tailnet: ""      // the account's tailnet name
    // Other machines: [{ name, dnsName, ip, online, os, link, lastSeen }], online first.
    property var peers: []
    property bool busy: false
    property string error: ""

    readonly property bool up: backendState === "Running"
    readonly property int peersOnline: peers.filter(p => p.online).length

    // unavailable / busy / up / login / down
    readonly property string status: backendState === "" ? "unavailable"
        : busy ? "busy"
        : up ? "up"
        : backendState === "NeedsLogin" ? "login"
        : "down"
    readonly property color statusColor: ({
        unavailable: Theme.textDisabled, busy: Theme.textSecondary, up: Theme.accent,
        login: Theme.warning, down: Theme.textDisabled
    })[status]

    readonly property string headline: {
        switch (status) {
        case "unavailable": return "Tailscale isn't running";
        case "busy": return backendState === "NeedsLogin" ? "Signing in…" : "Applying…";
        case "up": return "Connected";
        case "login": return "Signed out";
        default: return "Off";
        }
    }
    readonly property string subline: status === "unavailable" ? "systemctl status tailscaled"
        : status === "busy" && backendState === "NeedsLogin" ? "Finish in the browser"
        : status === "login" ? "Switch on to sign in"
        : up ? `${hostName} · ${ip}`
        : tailnet !== "" ? tailnet : "Switch on to connect"

    // ---- Polling -----------------------------------------------------------------------------
    function refresh() { if (!statusProc.running) statusProc.running = true; }

    Timer {
        interval: service.panelOpen ? 3000 : 30000
        repeat: true
        running: true
        onTriggered: service.refresh()
    }

    onPanelOpenChanged: if (panelOpen) refresh()
    Component.onCompleted: refresh()

    Process {
        id: statusProc
        command: ["tailscale", "status", "--json"]
        stdout: StdioCollector { onStreamFinished: service.parse(text) }
    }

    function parse(text) {
        let d;
        // No output (tailscaled stopped, CLI missing): unavailable.
        try { d = JSON.parse(text); } catch (e) { backendState = ""; peers = []; return; }
        backendState = d.BackendState ?? "";
        const self = d.Self ?? {};
        ip = (self.TailscaleIPs ?? d.TailscaleIPs ?? []).find(a => a.includes(".")) ?? "";
        hostName = self.HostName ?? "";
        dnsName = (self.DNSName ?? "").replace(/\.$/, "");
        tailnet = d.CurrentTailnet?.Name ?? "";
        const list = Object.values(d.Peer ?? {}).map(p => ({
            name: p.HostName ?? "?",
            dnsName: (p.DNSName ?? "").replace(/\.$/, ""),
            ip: (p.TailscaleIPs ?? []).find(a => a.includes(".")) ?? "",
            online: p.Online === true,
            os: p.OS ?? "",
            // Only a peer with traffic right now has a path; otherwise it is just "online".
            link: p.Online !== true ? "" : !p.Active ? "idle" : p.CurAddr ? "direct" : p.Relay ? `relay ${p.Relay}` : "",
            lastSeen: p.LastSeen ?? ""
        })).sort((a, b) => (b.online - a.online) || a.name.localeCompare(b.name));
        if (JSON.stringify(list) !== JSON.stringify(peers)) peers = list;
    }

    // ---- On / off ------------------------------------------------------------------------------
    property string errorLine: ""

    function setUp(on) {
        if (busy) return;
        busy = true;
        error = "";
        errorLine = "";
        toggleProc.command = on ? ["tailscale", "up", "--timeout=120s"] : ["tailscale", "down"];
        toggleProc.running = true;
    }

    Process {
        id: toggleProc
        stderr: SplitParser {
            onRead: line => {
                const url = (line.match(/https:\/\/login\.tailscale\.com\/\S+/) ?? [])[0];
                if (url) Qt.openUrlExternally(url);
                else if (line.trim() !== "" && service.errorLine === "") service.errorLine = line.trim();
            }
        }
        onExited: (code, status) => {
            if (code !== 0) service.error = service.errorLine || `tailscale exited with ${code}`;
            service.busy = false;
            service.refresh();
        }
    }

    // ---- Helpers ---------------------------------------------------------------------------------
    function openAdmin() { Qt.openUrlExternally("https://login.tailscale.com/admin/machines"); }

    // ISO time -> "5 min ago"; "never" for Tailscale's zero time.
    function ago(iso) {
        const t = Date.parse(iso);
        if (!(t > Date.parse("2000-01-01"))) return "never";
        const s = (Date.now() - t) / 1000;
        if (s < 60) return "just now";
        if (s < 3600) return `${Math.floor(s / 60)} min ago`;
        if (s < 86400) return `${Math.floor(s / 3600)} h ago`;
        return `${Math.floor(s / 86400)} d ago`;
    }
}
