// MediaService.qml: MPRIS players for the bar (Media.qml) and the media keys.
// Active player: a manual choice from the panel until that player disappears (or another
// one starts playing); else the most recently started of the playing ones; else the one
// used last. Starting playback in one player pauses the others.
// Media keys: `quickshell ipc -c bar call media playPause|next|previous`, so they always
// drive the same player as the widget. Checked against Quickshell 0.3.0.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property var players: Mpris.players.values

    // Bookkeeping by D-Bus name. Reassigned (never mutated) so bindings re-evaluate.
    property var startedAt: ({}) // when each player last started playing
    property var usedAt: ({})    // when each player was last playing or controlled
    property string pinned: ""   // manual choice from the panel tabs

    readonly property MprisPlayer active: {
        const list = players;
        if (!list.length) return null;
        const pin = list.find(p => p.dbusName === pinned);
        if (pin) return pin;
        const latest = (a, b, stamps) => (stamps[b.dbusName] ?? 0) > (stamps[a.dbusName] ?? 0) ? b : a;
        const playing = list.filter(p => p.isPlaying);
        if (playing.length) return playing.reduce((a, b) => latest(a, b, startedAt));
        return list.reduce((a, b) => latest(a, b, usedAt));
    }

    readonly property bool anyPlaying: players.some(p => p.isPlaying)

    onPlayersChanged: {
        if (pinned && !players.some(p => p.dbusName === pinned)) pinned = "";
    }

    function select(p) {
        pinned = p.dbusName;
        markUsed(p);
    }

    function markUsed(p) {
        usedAt = Object.assign({}, usedAt, { [p.dbusName]: Date.now() });
    }

    function onPlayingChanged(p) {
        markUsed(p);
        if (!p.isPlaying) return;
        startedAt = Object.assign({}, startedAt, { [p.dbusName]: Date.now() });
        if (pinned && pinned !== p.dbusName) pinned = "";
        for (const other of players)
            if (other !== p && other.isPlaying && other.canPause) other.pause();
    }

    Variants {
        model: root.players

        Connections {
            required property MprisPlayer modelData
            target: modelData
            function onIsPlayingChanged() { root.onPlayingChanged(modelData); }
        }
    }

    // Chromium never announces position changes; re-read it once a second while playing.
    Timer {
        interval: 1000
        repeat: true
        running: root.anyPlaying
        onTriggered: {
            for (const p of root.players)
                if (p.isPlaying) p.positionChanged();
        }
    }

    // ---- Controls ------------------------------------------------------------
    function togglePlaying(p) {
        if (!p) return;
        markUsed(p);
        p.togglePlaying();
    }

    function next(p) {
        if (!p?.canGoNext) return;
        markUsed(p);
        p.next();
    }

    // Restart the track after 3 s, otherwise go to the previous one.
    function previous(p) {
        if (!p) return;
        markUsed(p);
        if (p.canSeek && p.position > 3) p.position = 0;
        else if (p.canGoPrevious) p.previous();
    }

    function seek(p, seconds) {
        if (!p?.canSeek) return;
        p.position = Math.max(0, Math.min(p.length, seconds));
        p.positionChanged();
    }

    IpcHandler {
        target: "media"
        function playPause(): void { root.togglePlaying(root.active); }
        function next(): void { root.next(root.active); }
        function previous(): void { root.previous(root.active); }
    }

    // ---- Labels --------------------------------------------------------------
    function url(p) { return String(p?.metadata?.["xesam:url"] ?? ""); }

    function isBrowser(p) {
        return /chrom|brave|vivaldi|opera|edge/i.test(`${p?.identity} ${p?.desktopEntry} ${p?.dbusName}`);
    }

    function isMpv(p) { return /mpv/i.test(`${p?.identity} ${p?.dbusName}`); }

    function isLocal(p) { return url(p).startsWith("file://") || (isMpv(p) && !p.trackArtist); }

    // "Brave", "Chrome", "mpv", ...
    function appName(p) {
        if (!p) return "";
        const id = p.identity || p.desktopEntry || p.dbusName.replace(/^org\.mpris\.MediaPlayer2\./, "").split(".")[0];
        return id.replace(/^Google /, "");
    }

    // "YouTube Music · Brave", "mpv · local", "Brave".
    function sourceLabel(p) {
        if (!p) return "";
        if (isBrowser(p) && (url(p).includes("music.youtube.com") || p.trackTitle.includes("music.youtube.com")))
            return "YouTube Music · " + appName(p);
        if (isLocal(p)) return appName(p) + " · local";
        return appName(p);
    }

    function title(p) {
        if (!p) return "";
        if (isMpv(p) && !p.trackArtist && url(p)) {
            const file = decodeURIComponent(url(p).split("/").pop());
            if (file) return file;
        }
        return p.trackTitle || appName(p);
    }

    function artist(p) {
        if (!p) return "";
        return p.trackArtist || (isMpv(p) ? "Local file" : "");
    }

    // 86 -> "1:26", 3725 -> "1:02:05".
    function formatTime(seconds) {
        const s = Math.max(0, Math.floor(seconds || 0));
        const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, sec = s % 60;
        const pad = n => String(n).padStart(2, "0");
        return h > 0 ? `${h}:${pad(m)}:${pad(sec)}` : `${m}:${pad(sec)}`;
    }

    // ---- App volume (the player's PipeWire playback stream) ---------------------
    function keysOf(p) {
        return [p.identity, p.desktopEntry, p.dbusName.replace(/^org\.mpris\.MediaPlayer2\./, "").split(".")[0]]
            .filter(k => k && k.length >= 3).map(k => k.toLowerCase());
    }

    readonly property PwNode stream: {
        const p = active;
        if (!p) return null;
        const keys = keysOf(p);
        for (const node of Pipewire.nodes.values) {
            if (!node.audio || !node.isStream || node.isSink) continue;
            // properties is only filled once a node is tracked, so match on the name too.
            const names = [node.name, node.properties["application.name"], node.properties["application.process.binary"]]
                .map(n => String(n ?? "").toLowerCase()).filter(n => n.length >= 3);
            if (names.some(n => keys.some(k => n === k || n.includes(k) || k.includes(n))))
                return node;
        }
        return null;
    }

    PwObjectTracker { objects: root.stream ? [root.stream] : [] }

    readonly property bool streamAvailable: stream?.audio != null
    readonly property real streamVolume: streamAvailable ? Math.max(0, Math.min(1, stream.audio.volume)) : 0

    function setStreamVolume(v) {
        if (streamAvailable) stream.audio.volume = Math.max(0, Math.min(1, v));
    }
}
