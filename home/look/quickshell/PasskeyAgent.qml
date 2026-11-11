pragma Singleton
// (The pragma comes first: Quickshell stops looking for it at the first brace, and the
// protocol below has some.)
// PasskeyAgent.qml: the bar as linux-passkey's approval agent. The daemon connects to
// $XDG_RUNTIME_DIR/linux-passkey-agent.sock for each request (only when the bar listens; it
// falls back to its GTK dialog otherwise) and speaks JSON lines (linux-passkey src/agent.rs):
//   daemon -> bar  {"type":"ask","op":"sign-in","rp":…,"origin":…,"app":…,"accounts":[…],
//                   "user":…,"elsewhere":…,"fingerprint":…}
//   bar -> daemon  {"answer":"approve","account":…} | {"answer":"deny"} | {"answer":"elsewhere"}
//   daemon -> bar  {"type":"fingerprint","state":"waiting"|"no-match"|"match"|"error"}, {"type":"done"}
// A deny after an approve cancels the fingerprint wait. PasskeyPopup (under the Touch ID chip)
// shows the request; this only holds it. One request at a time: another one is denied.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: agent

    // The daemon's "ask" message, or null when no request is open.
    property var ask: null
    // "ask": the user decides. "finger": approved, the daemon waits for the finger.
    // "sent": approved without a finger step, waiting for "done".
    property string stage: ""
    // The last fingerprint state from the daemon (waiting / no-match / match / error).
    property string fingerState: ""
    // The screen the request opens on: the focused one when it came in.
    property string screenName: ""
    property var connection: null

    readonly property bool open: ask !== null

    SocketServer {
        active: true
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/linux-passkey-agent.sock"
        handler: Socket {
            id: socket
            parser: SplitParser { onRead: line => agent.received(socket, line) }
            onConnectedChanged: if (!connected) agent.ended(socket)
        }
    }

    function send(conn, message) {
        conn.write(JSON.stringify(message) + "\n");
        conn.flush();
    }

    function received(conn, line) {
        let m;
        try { m = JSON.parse(line); } catch (e) { return; }
        if (m.type === "ask") {
            if (connection && connection !== conn) {
                send(conn, { answer: "deny" });
                return;
            }
            connection = conn;
            // Hyprland may not have told us the focused monitor yet: then the first screen.
            screenName = Hyprland.focusedMonitor?.name || (Quickshell.screens[0]?.name ?? "");
            fingerState = "";
            stage = "ask";
            ask = m;
        } else if (conn !== connection) {
            return;
        } else if (m.type === "fingerprint") {
            stage = "finger";
            fingerState = m.state;
        } else if (m.type === "done") {
            ended(conn);
        }
    }

    function approve(account) {
        if (!connection || stage !== "ask") return;
        const message = { answer: "approve" };
        if (account) message.account = account;
        send(connection, message);
        stage = ask.fingerprint ? "finger" : "sent";
        if (stage === "finger") fingerState = "waiting";
    }

    // Deny, or cancel the fingerprint wait after an approve.
    function deny() {
        if (!connection) return;
        send(connection, { answer: "deny" });
        if (stage === "ask") stage = "sent";
    }

    function elsewhere() {
        if (!connection || stage !== "ask") return;
        send(connection, { answer: "elsewhere" });
        stage = "sent";
    }

    function ended(conn) {
        if (conn !== connection) return;
        connection = null;
        ask = null;
        stage = "";
        fingerState = "";
    }
}
