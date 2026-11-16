pragma Singleton
// ClaudeAgents.qml: the coding agents that Herdr sees, on this machine and the others, for
// the Claude dock (ClaudeDock.qml). One HerdrMachine per machine: this one's default
// session socket, the others' sockets forwarded over SSH (home/look/claude-dock.nix).
// Holds the agents as a ListModel and does what the dock asks: read an agent's screen,
// reply, open its terminal, start a new session.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    // ---- Machines -----------------------------------------------------------------------
    // Short names per hostname (the same list as home/look/claude-dock.nix); this machine's
    // cluster comes first.
    readonly property var labels: ({ nixAir: "AIR", nixPC: "PC", nixvps: "VPS", nuc: "NUC" })
    FileView { id: hostnameFile; path: "/etc/hostname"; blockLoading: true }
    readonly property string hostname: hostnameFile.text().trim()
    readonly property string localLabel: labels[hostname] ?? hostname.toUpperCase()

    HerdrMachine {
        id: local
        label: root.localLabel
        socketPath: Quickshell.env("CLAUDE_DOCK_HERDR_SOCKET")
            || Quickshell.env("HOME") + "/.config/herdr/herdr.sock"
        onAgentsChanged: root.sync()
    }
    // Other machines: their Herdr socket forwarded over SSH to
    // $XDG_RUNTIME_DIR/herdr-<LABEL>.sock (herdr-forward-<LABEL>, claude-dock.nix).
    readonly property var remoteHosts: Object.keys(labels).filter(h => h !== hostname)
    Variants {
        id: remotes
        model: root.remoteHosts
        HerdrMachine {
            required property string modelData
            readonly property string host: modelData
            label: root.labels[modelData]
            socketPath: `${Quickshell.env("XDG_RUNTIME_DIR")}/herdr-${label}.sock`
            onAgentsChanged: root.sync()
        }
    }
    readonly property var machines: [local].concat(remotes.instances)

    // ---- Agents -----------------------------------------------------------------------
    // key ("<label>:<pane>"), name, host, status ("working" | "yours" | "idle"),
    // herdrStatus (working, blocked, done, idle, unknown), lastLine, since (ms, last status
    // change), pane, machine (index into `machines`).
    ListModel { id: agents }
    readonly property ListModel model: agents

    // Bumped on every change, so layouts that read the model re-evaluate.
    property int revision: 0
    property real now: Date.now()

    // Yours: it asks something (blocked), or it finished and you haven't looked. Herdr's own
    // "done" misses most finishes: one in the pane focused in its window counts as seen
    // even when no one looks at that window (it reports idle). So the dock keeps what you
    // saw: the agent's completion_seq when you last clicked its dot or focused its window.
    function statusOf(a, key) {
        if (a.agent_status === "working") return "working";
        if (a.agent_status === "blocked" || a.agent_status === "done") return "yours";
        return (a.completion_seq ?? 0) > (seenSeq[key] ?? 0) ? "yours" : "idle";
    }

    // key -> completion_seq seen; kept across bar restarts (pane ids are never reused).
    property var seenSeq: ({})
    FileView {
        id: seenFile
        path: Quickshell.statePath("claude-dock-seen.json")
        blockLoading: true
        printErrors: false
        Component.onCompleted: { try { root.seenSeq = JSON.parse(text() || "{}"); } catch (e) {} }
    }

    function markSeen(key) {
        const a = agentAt(key);
        if (!a || (seenSeq[key] ?? 0) >= a.completion) return;
        // Prune agents that are gone, but only on machines that answer: one that is off
        // (asleep, unreachable) keeps its agents' entries for when it comes back.
        const live = {};
        for (let i = 0; i < agents.count; i++) live[agents.get(i).key] = true;
        const offline = machines.filter(m => !m.online).map(m => m.label + ":");
        const next = {};
        for (const k of Object.keys(seenSeq))
            if (live[k] || offline.some(p => k.startsWith(p))) next[k] = seenSeq[k];
        next[key] = a.completion;
        seenSeq = next;
        seenFile.setText(JSON.stringify(next));
        sync();
    }

    // Its window focused (the one a dot click opens, "herdr <LABEL> <pane>"): seen. Checked
    // on every focus change, and when an agent finishes (you may be looking at it).
    Connections {
        target: Hyprland
        function onRawEvent(event) { if (event.name === "activewindowv2") root.checkActive(); }
    }
    // One check at a time; a focus change during one runs another after it, so the ring
    // always ends on the window focused last.
    property bool activeAgain: false
    function checkActive() {
        if (activeAttach.running) activeAgain = true;
        else activeAttach.running = true;
    }
    Process {
        id: activeAttach
        onRunningChanged: if (!running && root.activeAgain) { root.activeAgain = false; running = true; }
        command: ["sh", "-c", "hyprctl activewindow -j | jq -r 'select(.class == \"herdr-attach\") | .initialTitle'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.trim().match(/^herdr (\S+) (\S+)$/);
                root.activeKey = m ? `${m[1]}:${m[2]}` : "";
                if (m) root.markSeen(root.activeKey);
            }
        }
    }
    // ---- Fullscreen ---------------------------------------------------------------------
    // Screens (monitor names) showing a fullscreen window, on their regular workspace or a
    // shown special one (the drop-down terminal lives on special:dropterm, so the regular
    // workspace's hasFullscreen misses it). The dock hides on those. Both ways at once:
    // Hyprland's events update what is known (which workspaces hold a fullscreen window,
    // which are shown where) and decide before anything is asked; the check (hyprctl)
    // then confirms it. Hyprland has at most one fullscreen window per workspace, so a
    // window leaving fullscreen clears its workspace.
    property var fullscreenScreens: []
    property var fullscreenWorkspaces: []   // workspace names holding a fullscreen window
    property var shownRegular: ({})         // monitor -> its regular workspace's name
    property var shownSpecial: ({})         // monitor -> its shown special workspace ("" none)
    readonly property var fullscreenEvents: [
        "fullscreen", "activespecialv2", "workspacev2", "focusedmon",
        "openwindow", "closewindow", "movewindowv2", "changefloatingmode",
    ]
    function decide(monitor) {
        const ws = fullscreenWorkspaces;
        const hide = ws.includes(shownRegular[monitor]) || (!!shownSpecial[monitor] && ws.includes(shownSpecial[monitor]));
        const others = fullscreenScreens.filter(n => n !== monitor);
        fullscreenScreens = hide ? others.concat([monitor]) : others;
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!root.fullscreenEvents.includes(event.name)) return;
            const mon = Hyprland.focusedMonitor?.name ?? "";
            const f = event.data.split(",");
            if (event.name === "fullscreen") {
                // The active window: on the shown special workspace if there is one.
                const ws = root.shownSpecial[mon] || root.shownRegular[mon];
                const rest = root.fullscreenWorkspaces.filter(n => n !== ws);
                root.fullscreenWorkspaces = event.data === "1" ? rest.concat([ws]) : rest;
                root.decide(mon);
            } else if (event.name === "activespecialv2") {   // id,name,monitor; name "" closed
                root.shownSpecial = Object.assign({}, root.shownSpecial, { [f[2]]: f[1] });
                root.decide(f[2]);
            } else if (event.name === "workspacev2") {       // id,name, on the focused monitor
                root.shownRegular = Object.assign({}, root.shownRegular, { [mon]: f[1] });
                root.decide(mon);
            }
            root.checkFullscreen();
        }
    }
    property bool fullscreenAgain: false
    function checkFullscreen() {
        if (fullscreenCheck.running) fullscreenAgain = true;
        else fullscreenCheck.running = true;
    }
    Process {
        id: fullscreenCheck
        running: true
        onRunningChanged: if (!running && root.fullscreenAgain) { root.fullscreenAgain = false; running = true; }
        command: ["sh", "-c", `
            jq -nc --argjson m "$(hyprctl monitors -j)" --argjson c "$(hyprctl clients -j)" '
              [$c[] | select(.fullscreen != 0 and .mapped and (.hidden | not))] as $full
              | { workspaces: [$full[].workspace.name] | unique,
                  regular: [$m[] | { key: .name, value: .activeWorkspace.name }] | from_entries,
                  special: [$m[] | { key: .name, value: .specialWorkspace.name }] | from_entries,
                  screens: [$m[] as $mon | select(any($full[]; .monitor == $mon.id
                      and (.workspace.id == $mon.activeWorkspace.id or .workspace.name == $mon.specialWorkspace.name)))
                    | $mon.name] }'`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    root.fullscreenWorkspaces = r.workspaces;
                    root.shownRegular = r.regular;
                    root.shownSpecial = r.special;
                    root.fullscreenScreens = r.screens;
                } catch (e) {}
            }
        }
    }

    // The agent whose window has focus ("" for any other window): ringed in the dock.
    property string activeKey: ""
    Component.onCompleted: checkActive()

    function sync() {
        const seen = {};
        let finished = false;
        machines.forEach((m, mi) => {
            for (const a of m.agents) {
                if (!a.agent) continue; // a pane without an agent in it
                const key = `${m.label}:${a.pane_id}`;
                seen[key] = true;
                const row = {
                    key: key,
                    name: a.name || (a.cwd ?? "").split("/").pop() || a.display_agent || a.agent,
                    host: m.label,
                    herdrStatus: a.agent_status,
                    status: statusOf(a, key),
                    completion: a.completion_seq ?? 0,
                    title: a.terminal_title_stripped ?? "",
                    folder: root.homeRelative(a.cwd ?? ""),
                    kind: a.agent ?? "",
                    pane: a.pane_id,
                    machine: mi,
                };
                const i = indexOf(key);
                if (i < 0) {
                    agents.append(Object.assign(row, { lastLine: "", turn: "", since: Date.now() }));
                } else {
                    const old = agents.get(i);
                    if (old.status !== row.status) agents.setProperty(i, "since", Date.now());
                    if (row.completion > old.completion) finished = true;
                    for (const k of Object.keys(row))
                        if (old[k] !== row[k]) agents.setProperty(i, k, row[k]);
                }
            }
        });
        for (let i = agents.count - 1; i >= 0; i--)
            if (!seen[agents.get(i).key]) agents.remove(i);
        revision++;
        if (finished) checkActive();
    }

    function indexOf(key) {
        for (let i = 0; i < agents.count; i++)
            if (agents.get(i).key === key) return i;
        return -1;
    }

    // Amber agents, longest waiting first.
    function waiting() {
        const out = [];
        for (let i = 0; i < agents.count; i++)
            if (agents.get(i).status === "yours") out.push(agents.get(i));
        return out.sort((a, b) => a.since - b.since);
    }

    // ---- Actions ----------------------------------------------------------------------
    function agentAt(key) {
        const i = indexOf(key);
        return i < 0 ? null : agents.get(i);
    }

    function homeRelative(path) {
        const home = Quickshell.env("HOME");
        return path === home ? "~" : path.startsWith(home + "/") ? "~" + path.slice(home.length) : path;
    }

    // From the agent's screen (Claude Code): its last "● …" block (a message, or the tool
    // call it is running, with its description), and the running turn's time and tokens
    // ("✻ Sautéing… (6m 56s · ↓ 9.9k tokens)" -> "6m 56s · 9.9k tokens").
    // The visible screen only: a longer read makes Herdr scroll the agent's history, which
    // takes a while, and Herdr refuses an attach while a read runs.
    property var reading: ({})     // key -> true while its read runs
    property string flyAfterRead: "" // a click that came during that read
    function readLast(key) {
        const a = agentAt(key);
        if (!a || reading[key]) return;
        reading = Object.assign({}, reading, { [key]: true });
        machines[a.machine].request("agent.read", { target: a.pane, source: "visible" }, r => {
            const left = Object.assign({}, reading);
            delete left[key];
            reading = left;
            if (flyAfterRead === key) { flyAfterRead = ""; root.fly(key); }
            const text = r?.read?.text ?? "";
            const lines = text.split("\n");
            let start = -1;
            for (let i = lines.length - 1; i >= 0; i--)
                if (lines[i].startsWith("● ")) { start = i; break; }
            let msg = "";
            if (start >= 0) {
                const block = [lines[start].slice(2)];
                for (let i = start + 1; i < lines.length && lines[i].startsWith("  "); i++)
                    block.push(lines[i].trim());
                msg = block.join(" ").replace(/\s+/g, " ").trim();
            }
            let turn = "";
            for (let i = lines.length - 1; i >= 0; i--) {
                const t = lines[i].match(/^\S+ \S+… \((.+)\)\s*$/);
                if (t) { turn = t[1].replace(/[↓↑]\s*/g, ""); break; }
            }
            const i = indexOf(key);
            if (i >= 0) {
                agents.setProperty(i, "lastLine", msg);
                agents.setProperty(i, "turn", turn);
                revision++;
            }
        });
    }

    function reply(key, text) {
        const a = agentAt(key);
        if (!a || !text.trim()) return;
        machines[a.machine].request("agent.prompt", { target: a.pane, text: text }, (r, error) => {
            if (!r) notify(`Reply to ${a.title || a.name} not sent`, error);
        });
    }

    // Failures the dock can't show itself: a notification (the bar shows it).
    function notify(summary, body) {
        Quickshell.execDetached(["notify-send", "--app-name=Claude dock", summary, body || "Herdr did not answer."]);
    }

    // Fly to the session: Herdr focuses the pane (and marks it seen), then a window with just
    // that agent's terminal comes to the front, or opens: Alacritty running `herdr agent
    // attach` (over `ssh -t` for another machine). --takeover moves it from an attach left
    // open elsewhere. Closing the window (Super+Q) only detaches: the agent keeps running.
    function fly(key) {
        const a = agentAt(key);
        if (!a) return;
        if (reading[key]) { flyAfterRead = key; return; }
        markSeen(key);
        flyTo(a.machine, a.pane);
    }
    function flyTo(machine, pane) {
        const m = machines[machine];
        m.request("agent.focus", { target: pane });
        attach.environment = {
            DOCK_TITLE: `herdr ${m.label} ${pane}`,
            DOCK_PANE: pane,
            DOCK_SSH: m === local ? "" : m.host,
        };
        attach.running = true;
    }

    // ---- New session ("+") --------------------------------------------------------------
    // Machines for the picker: index into `machines`, label, whether its Herdr answers.
    readonly property var machineInfo: machines.map((m, i) => ({ i: i, label: m.label, online: m.online }))

    // Folders of that machine's agents, most recent agents first, home-relative ("~/…").
    function recentFolders(machine) {
        const out = [];
        for (const a of machines[machine]?.agents ?? []) {
            const cwd = homeRelative(a.cwd ?? "");
            if (cwd && !out.includes(cwd)) out.push(cwd);
        }
        return out.slice(0, 4);
    }

    // A workspace in `folder` on that machine, Claude started in its pane, then its window.
    // "~" paths use this machine's home (the same /home/andrew everywhere).
    function startSession(machine, folder) {
        const m = machines[machine];
        const home = Quickshell.env("HOME");
        folder = (folder ?? "").trim();
        const cwd = !folder || folder === "~" ? home
            : folder.startsWith("~/") ? home + folder.slice(1) : folder;
        const base = cwd.split("/").pop().toLowerCase().replace(/[^a-z0-9_-]+/g, "-").replace(/^[^a-z]+/, "") || "claude";
        const name = `${base.slice(0, 26)}-${Math.random().toString(36).slice(2, 6)}`;
        m.request("workspace.create", { cwd: cwd, focus: false }, (r, error) => {
            const pane = r?.root_pane?.pane_id;
            if (!pane) { notify(`No new session on ${m.label}`, error); return; }
            m.request("agent.start", { name: name, kind: "claude", pane_id: pane, timeout_ms: 60000 }, (s, startError) => {
                // Opened even if the start didn't confirm: the terminal shows what happened.
                if (!s) notify(`Claude may not have started on ${m.label}`, startError);
                root.flyTo(machine, pane);
            });
        });
    }

    Process {
        id: attach
        command: ["bash", "-c", `
            # Its window, by the title it was opened with.
            pid=$(hyprctl clients -j | jq -r --arg t "$DOCK_TITLE" \
                'first(.[] | select(.class == "herdr-attach" and .initialTitle == $t) | .pid) // empty')
            if [ -n "$pid" ]; then
                hyprctl dispatch "hl.dsp.focus({ window = \"pid:$pid\" })" >/dev/null
                exit 0
            fi
            cmd=(herdr agent attach "$DOCK_PANE" --takeover)
            [ -n "$DOCK_SSH" ] && cmd=(ssh -t "$DOCK_SSH" "\${cmd[@]}")
            # An attach failing within 3 s is retried (Herdr refuses one while it reads the
            # terminal); one that still fails keeps its window, with Herdr's message, until Enter.
            keep='for i in 1 2 3 4; do t=$(date +%s); "$@" && exit 0; s=$?; [ $(( $(date +%s) - t )) -ge 3 ] && break; sleep 1; done; printf "\\n[attach exited with %s; Enter closes]" "$s"; read -r _'
            setsid -f alacritty --class herdr-attach --title "$DOCK_TITLE" -e sh -c "$keep" sh "\${cmd[@]}" \
                >/dev/null 2>&1 </dev/null`]
    }
}
