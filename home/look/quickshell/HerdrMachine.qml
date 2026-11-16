// HerdrMachine.qml: the agents of one Herdr server, over its API socket (JSON lines, one
// request per connection; herdr api schema). A long-lived connection subscribes to pane
// events (agents appearing and leaving) and to each agent pane's status changes; any event
// re-reads `agent.list`. Retries every 5 s while the server is down.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: m

    required property string label      // "AIR", "PC", "VPS", "NUC"
    required property string socketPath
    property bool online: false
    property var agents: []             // AgentInfo objects from the last agent.list

    // ---- Requests -----------------------------------------------------------------------
    // One connection per request; `done(result, error)` gets `.result`, or null and Herdr's
    // error message (empty when the server didn't answer).
    function request(method, params, done) {
        const s = requestSocket.createObject(m, {
            path: m.socketPath,
            payload: JSON.stringify({ id: method, method: method, params: params ?? {} }) + "\n",
            done: done ?? (() => {}),
        });
        s.connected = true;
    }

    Component {
        id: requestSocket
        Socket {
            id: rs
            property string payload
            property var done
            property bool answered: false
            function finish(result, error) {
                if (answered) return;
                answered = true;
                done(result, error ?? "");
                Qt.callLater(() => rs.destroy());
            }
            onConnectedChanged: {
                if (connected) { write(payload); flush(); }
                else finish(null);
            }
            onError: finish(null)
            parser: SplitParser {
                onRead: line => {
                    let msg = {};
                    try { msg = JSON.parse(line); } catch (e) {}
                    rs.finish(msg.result ?? null, msg.error?.message ?? "");
                }
            }
        }
    }

    function refresh() {
        request("agent.list", {}, r => {
            if (!r || !m.online) return;   // a late answer from a server that went away
            m.agents = r.agents ?? [];
            const panes = m.agents.map(a => a.pane_id).sort().join(" ");
            if (panes !== m.watched) m.resubscribe();
        });
    }

    // ---- Events -------------------------------------------------------------------------
    property string watched: ""   // agent panes the event connection subscribed to

    function subscriptions() {
        const subs = ["pane.created", "pane.agent_detected", "pane.closed", "pane.exited", "pane.updated"]
            .map(t => ({ type: t }));
        for (const a of agents) subs.push({ type: "pane.agent_status_changed", pane_id: a.pane_id });
        return subs;
    }

    property bool resubscribing: false
    function resubscribe() {
        resubscribing = true;
        events.connected = false;   // onConnectedChanged reconnects at once
    }

    Socket {
        id: events
        path: m.socketPath
        onConnectedChanged: {
            if (connected) {
                m.watched = m.agents.map(a => a.pane_id).sort().join(" ");
                write(JSON.stringify({ id: "sub", method: "events.subscribe",
                                       params: { subscriptions: m.subscriptions() } }) + "\n");
                flush();
            } else if (m.resubscribing) {
                m.resubscribing = false;
                Qt.callLater(() => events.connected = true);
            } else {
                m.online = false;
            }
        }
        parser: SplitParser {
            onRead: line => {
                let msg;
                try { msg = JSON.parse(line); } catch (e) { return; }
                if (msg.id === "sub") {
                    m.online = !!msg.result;
                    if (m.online) m.refresh();
                } else if (msg.event) {
                    debounce.restart();
                }
            }
        }
    }

    // Several events arrive together (a status change also updates the pane).
    Timer { id: debounce; interval: 120; onTriggered: m.refresh() }
    // Retries while the server is down (or not started yet).
    Timer {
        interval: 5000
        repeat: true
        running: !m.online
        onTriggered: if (!events.connected) events.connected = true
    }
    Component.onCompleted: events.connected = true
    onOnlineChanged: if (!online) agents = []
}
