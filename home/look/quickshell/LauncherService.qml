// LauncherService.qml: data for the app launcher (Launcher.qml).
// - Pinned apps: the "pinned" id list in ~/.config/quickshell/launcher/launcher.json,
//   resolved through desktop entries. Watched, so edits apply live; no pinning in the UI.
// - Commands from `compgen -c` (login bash, minus shell keywords, builtins and pinned
//   ids), re-read every time the launcher opens (~60 ms).
// - Fuzzy matching in JS and launching. Checked against Quickshell 0.3.0.
// Keep braces out of this header: Quickshell stops looking for `pragma Singleton` at the first one.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: service

    readonly property string configPath:
        (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/quickshell/launcher/launcher.json"

    // Ask Launcher.qml to open or close (e.g. from the system menu), without going through IPC.
    signal toggleRequested()

    property var pinnedIds: []
    property string configError: ""

    // ---- Pinned ---------------------------------------------------------------------
    FileView {
        path: service.configPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const ids = JSON.parse(text()).pinned ?? [];
                service.pinnedIds = ids.filter(id => typeof id === "string" && id.trim() !== "").map(id => id.trim());
                service.configError = "";
            } catch (e) {
                service.configError = `invalid JSON in ${service.configPath}`;
            }
        }
        onLoadFailed: error => service.configError = `cannot read ${service.configPath}`
    }

    // { id, name, icon, entry } per pinned id; entry is null when no desktop entry matches.
    readonly property var pinned: {
        DesktopEntries.applications.values; // re-resolve when desktop entries change
        return pinnedIds.map(id => {
            const entry = DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id) ?? service.looseLookup(id);
            return {
                id: id,
                entry: entry,
                name: entry?.name || id,
                icon: entry ? Quickshell.iconPath(entry.icon, "application-x-executable") : "",
            };
        });
    }

    // heuristicLookup() misses short names like "brave" (brave-browser.desktop): also accept
    // an entry whose id starts with "<id>-" or "<id>.", or whose name is <id>, ignoring case.
    function looseLookup(id) {
        const want = id.toLowerCase();
        const apps = DesktopEntries.applications.values.filter(e => !e.noDisplay);
        return apps.find(e => e.id.toLowerCase().startsWith(want + "-") || e.id.toLowerCase().startsWith(want + "."))
            ?? apps.find(e => e.name.toLowerCase() === want)
            ?? null;
    }

    // ---- Commands -------------------------------------------------------------------
    property var allCommands: [] // sorted, unique, without keywords/builtins
    readonly property var commands: allCommands.filter(c => !pinnedIds.includes(c))
    // Pre-built "no query" results, so an empty query costs nothing.
    readonly property var commandItems: commands.map(c => ({ name: c, indices: [], score: 0 }))

    function refreshCommands() { if (!lister.running) lister.running = true; }

    Component.onCompleted: refreshCommands()

    Process {
        id: lister
        // Everything bash can run, minus keywords (if, then, {, [[) and builtins.
        command: ["bash", "-lc", 'comm -23 <(compgen -c | sort -u) <( { compgen -k; compgen -b; } | sort -u)']
        stdout: StdioCollector {
            onStreamFinished: {
                const list = text.split("\n").filter(c => c !== "");
                if (list.join("\n") !== service.allCommands.join("\n")) service.allCommands = list;
            }
        }
    }

    // ---- Search ---------------------------------------------------------------------
    // { pinned: [{ app, indices, onCommand, score }], commands: [{ name, indices, score }],
    //   best: flat index to select first: the best pinned match if any, else the best command }
    function search(query) {
        const q = query.trim();
        if (q === "") {
            return {
                pinned: pinned.map(app => ({ app: app, indices: [], onCommand: false, score: 0 })),
                commands: commandItems,
                best: 0,
            };
        }

        const pinnedHits = [];
        for (const app of pinned) {
            let m = fuzzy(q, app.name), onCommand = false;
            if (!m && app.name !== app.id) { m = fuzzy(q, app.id); onCommand = m !== null; }
            if (m) pinnedHits.push({ app: app, indices: m.indices, onCommand: onCommand, score: m.score });
        }
        pinnedHits.sort((a, b) => b.score - a.score);

        const hits = [];
        for (const name of commands) {
            const m = fuzzy(q, name);
            if (m) hits.push({ name: name, indices: m.indices, score: m.score });
        }
        hits.sort((a, b) => (b.score - a.score) || (a.name < b.name ? -1 : 1));

        // Pinned apps win: the selection starts on the best pinned match whenever one matches,
        // otherwise on the best command (both lists are sorted, so that is index 0 either way).
        return { pinned: pinnedHits, commands: hits, best: 0 };
    }

    // Case-insensitive subsequence match. Tries the greedy match from each occurrence of
    // the first query character (so "fox" can land on "fire-fox" instead of "f...o...x")
    // and keeps the best score:
    //   +1 per matched character, +8 if it directly follows the previous match,
    //   +6 at the start or after - _ . or a space,
    //   -0.3 per character spanned between the first and last match,
    //   -0.05 per character of the string.
    function fuzzy(query, text) {
        const q = query.toLowerCase(), s = text.toLowerCase();
        if (q.length > s.length) return null;
        let best = null;
        for (let start = s.indexOf(q[0]), tries = 0; start !== -1 && tries < 8; start = s.indexOf(q[0], start + 1), tries++) {
            const indices = [start];
            let from = start + 1;
            for (let i = 1; i < q.length; i++) {
                const k = s.indexOf(q[i], from);
                if (k < 0) return best; // no match from here means none from later starts
                indices.push(k);
                from = k + 1;
            }
            let score = -0.3 * (indices[indices.length - 1] - indices[0]) - 0.05 * s.length;
            for (let i = 0; i < indices.length; i++) {
                const p = indices[i];
                score += 1;
                if (i > 0 && p === indices[i - 1] + 1) score += 8;
                if (p === 0 || "-_. ".includes(s[p - 1])) score += 6;
            }
            if (!best || score > best.score) best = { score: score, indices: indices };
        }
        return best;
    }

    // StyledText for `text` with the characters at `indices` in lime.
    function highlight(text, indices) {
        const esc = c => c === "&" ? "&amp;" : c === "<" ? "&lt;" : c === ">" ? "&gt;" : c;
        if (!indices || !indices.length) return text.split("").map(esc).join("");
        const set = new Set(indices);
        let out = "", open = false;
        for (let i = 0; i < text.length; i++) {
            const hit = set.has(i);
            if (hit && !open) { out += `<font color="${Theme.accent}">`; open = true; }
            if (!hit && open) { out += "</font>"; open = false; }
            out += esc(text[i]);
        }
        return open ? out + "</font>" : out;
    }

    // ---- Launch ---------------------------------------------------------------------
    // Everything is started in its own transient systemd scope. Started directly, an app
    // would live in quickshell.service's cgroup and be killed whenever the bar restarts.
    function spawn(argv) {
        Quickshell.execDetached(["systemd-run", "--user", "--scope", "--quiet", "--collect", "--"].concat(argv));
    }

    // A desktop entry's command (field codes already resolved by Quickshell); terminal apps
    // run in alacritty.
    function launchEntry(entry) {
        const argv = Array.from(entry.command);
        spawn(entry.runInTerminal ? ["alacritty", "-e"].concat(argv) : argv);
    }

    function launchPinned(app) {
        if (app.entry) launchEntry(app.entry);
        else run(app.id);
    }

    // Commands and "run in a shell": through a login shell for the full PATH.
    function run(cmd) {
        spawn(["bash", "-lc", cmd]);
    }
}
