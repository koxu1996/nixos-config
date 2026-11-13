// Claude dock prototype: a bump on the right screen edge with one dot per coding agent that
// Herdr sees, amber when it waits for you. Run beside the bar:
//
//   quickshell -p ~/nixos/home/look/quickshell/dev/claude-dock
//
// CLAUDE_DOCK_HERDR_SOCKET points it at another Herdr session's socket (default: the
// default session, ~/.config/herdr/herdr.sock).
//
// "Next waiting" is a Hyprland global shortcut (no key bound yet):
//   hyprctl dispatch 'hl.dsp.global("claude-dock:next-waiting")'
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    id: root

    // Edits reload the prototype; say so only when a reload fails.
    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup(); }
    }

    // ---- Machines -----------------------------------------------------------------------
    // Short names per hostname; this machine's cluster comes first.
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
    // $XDG_RUNTIME_DIR/herdr-<LABEL>.sock (ssh -L, one user service each).
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

    // Bumped on every change, so layouts that read the model re-evaluate.
    property int revision: 0
    property real now: Date.now()

    // Yours: it asks something (blocked) or finished and you haven't looked (done).
    function statusOf(herdrStatus) {
        return herdrStatus === "working" ? "working"
            : herdrStatus === "blocked" || herdrStatus === "done" ? "yours" : "idle";
    }

    function sync() {
        const seen = {};
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
                    status: statusOf(a.agent_status),
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
                    for (const k of Object.keys(row))
                        if (old[k] !== row[k]) agents.setProperty(i, k, row[k]);
                }
            }
        });
        for (let i = agents.count - 1; i >= 0; i--)
            if (!seen[agents.get(i).key]) agents.remove(i);
        revision++;
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
    function readLast(key) {
        const a = agentAt(key);
        if (!a) return;
        machines[a.machine].request("agent.read", { target: a.pane, source: "recent_unwrapped", lines: 80 }, r => {
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
        if (a && text.trim()) machines[a.machine].request("agent.prompt", { target: a.pane, text: text });
    }

    // Fly to the session: Herdr focuses the pane (and marks it seen), then a window with just
    // that agent's terminal comes to the front, or opens: Alacritty running `herdr agent
    // attach` (over `ssh -t` for another machine). --takeover moves it from an attach left
    // open elsewhere. Closing the window (Super+Q) only detaches: the agent keeps running.
    function fly(key) {
        const a = agentAt(key);
        if (a) flyTo(a.machine, a.pane);
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
        m.request("workspace.create", { cwd: cwd, focus: false }, r => {
            const pane = r?.root_pane?.pane_id;
            if (!pane) { console.warn("claude-dock: workspace.create failed on", m.label); return; }
            m.request("agent.start", { name: name, kind: "claude", pane_id: pane, timeout_ms: 60000 }, s => {
                if (!s) console.warn("claude-dock: agent.start failed on", m.label, pane);
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
            setsid -f alacritty --class herdr-attach --title "$DOCK_TITLE" -e "\${cmd[@]}" \
                >/dev/null 2>&1 </dev/null`]
    }

    // ---- Next waiting -----------------------------------------------------------------
    // Opens the flyout for the longest-waiting agent on the focused screen; again: the next.
    signal hotkey(string key, string screenName)
    property string hotkeyId: ""

    GlobalShortcut {
        appid: "claude-dock"
        name: "next-waiting"
        description: "Claude dock: reply to the next waiting session"
        onPressed: {
            const list = root.waiting();
            if (!list.length) return;
            const at = list.findIndex(a => a.key === root.hotkeyId);
            root.hotkeyId = list[(at + 1) % list.length].key;
            root.hotkey(root.hotkeyId, Hyprland.focusedMonitor?.name ?? "");
        }
    }

    Variants {
        model: Quickshell.screens
        ClaudeDock {
            required property var modelData
            screen: modelData
            store: root
            model: agents
        }
    }
}
