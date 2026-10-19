// GlowService.qml: state, schedule and hyprsunset IPC for the Glow widget.
//
// - Profiles come from ~/.config/quickshell/glow/profiles.json (read-only here,
//   reloaded when the file changes). Times are "HH:MM" or "sunset", where sunset is
//   computed locally (NOAA formula) from the latitude/longitude in the same file.
// - Mode and manual values persist in Quickshell's state dir (glow.json).
// - hyprsunset runs with no profiles of its own; this service owns the schedule and
//   re-applies the colour temperature every minute (also covers hyprsunset restarts).
// - Mode (Schedule / Manual) is about colour temperature only; profiles are colour only.
// - Brightness (hosts with a backlight, Host.glowBrightness) is independent of the mode: it is
//   the panel backlight, read with `brightnessctl -m`
//   (so the brightness keys show up) and set with `brightnessctl set N%` (hyprsunset's gamma scales
//   the colour matrix, which Apple's display coprocessor ignores). It is applied only when
//   the user moves the slider, so the brightness keys keep working.
// - Modes: Schedule and Manual. In Manual, Reset restores original colours (hyprsunset
//   identity) until the temperature slider is moved again; brightness is left alone.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: service

    // ---- Limits ---------------------------------------------------------------
    readonly property int minTemperature: 1000
    readonly property int maxTemperature: 10000
    readonly property int neutralTemperature: 6500
    readonly property int minBrightness: 0 // 0 may switch the panel backlight off entirely
    readonly property int maxBrightness: 100

    // ---- Config: profiles + location ------------------------------------------
    readonly property string configPath:
        (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/quickshell/glow/profiles.json"

    property var config: ({ latitude: null, longitude: null, profiles: [] })
    property string configError: ""

    FileView {
        id: configFile
        path: service.configPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: service.parseConfig(text())
        onLoadFailed: error => service.configError = `cannot read ${service.configPath}`
    }

    function parseConfig(text) {
        try {
            const json = JSON.parse(text);
            const profiles = (json.profiles ?? []).filter(p =>
                typeof p.name === "string" && typeof p.time === "string"
                && Number.isFinite(p.temperature));
            config = {
                latitude: Number.isFinite(json.latitude) ? json.latitude : null,
                longitude: Number.isFinite(json.longitude) ? json.longitude : null,
                profiles: profiles,
            };
            configError = profiles.length ? "" : "no valid profiles in config";
        } catch (e) {
            configError = `invalid JSON in ${configPath}`;
        }
        refresh();
    }

    // ---- State (live) + persistence ------------------------------------------------
    // The live state is plain properties. The file is read once at startup and written
    // with a short debounce; it never feeds back into the running state (overlapping
    // async writes used to reload stale values and briefly flip the mode back).
    property string mode: "schedule"     // "schedule" | "manual"
    property bool manualNeutral: false    // Manual with original colours (after Reset)
    property int manualTemperature: 4500
    property bool stateRestored: false

    FileView {
        id: stateFile
        path: Quickshell.statePath("glow.json")
        onLoaded: service.restoreState()
        onLoadFailed: error => service.restoreState() // first run: keep defaults

        JsonAdapter {
            id: persisted
            property string mode: "schedule" // "disabled" from older versions = manual + neutral
            property bool manualNeutral: false
            property int manualTemperature: 4500
        }
    }

    function restoreState() {
        if (stateRestored) return;
        stateRestored = true;
        mode = persisted.mode === "schedule" ? "schedule" : "manual";
        manualNeutral = persisted.manualNeutral || persisted.mode === "disabled";
        manualTemperature = persisted.manualTemperature;
        refresh();
    }

    Timer {
        id: saveDebounce
        interval: 400
        onTriggered: {
            persisted.mode = service.mode;
            persisted.manualNeutral = service.manualNeutral;
            persisted.manualTemperature = service.manualTemperature;
            stateFile.writeAdapter();
        }
    }

    function changed() {
        if (stateRestored) saveDebounce.restart(); // never overwrite the file before it was read
        refresh();
    }

    function setMode(m) {
        if (!["schedule", "manual"].includes(m)) return;
        // Schedule -> Manual starts from the colour currently on screen, so switching
        // causes no visible change: the active profile's temperature, or original colours.
        if (m === "manual" && mode === "schedule") {
            manualNeutral = activeProfile === null;
            if (activeProfile) manualTemperature = activeProfile.temperature;
        }
        mode = m;
        changed();
    }
    function setManualTemperature(k) {
        manualTemperature = Math.round(clamp(k, minTemperature, maxTemperature) / 100) * 100;
        manualNeutral = false; // moving the slider tints again
        changed();
    }
    // Manual only: back to original colours (identity); brightness is left as it is.
    function resetManual() {
        manualNeutral = true;
        changed();
    }

    // ---- Schedule -----------------------------------------------------------------
    property date now: new Date()

    Timer {
        interval: 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { service.now = new Date(); service.refresh(); }
    }

    // Profiles with resolved minutes-after-midnight, sorted by time.
    readonly property var schedule: {
        const out = [];
        for (const p of config.profiles) {
            const minutes = p.time === "sunset" ? sunsetMinutes(now, config.latitude, config.longitude)
                                                : parseClock(p.time);
            if (minutes === null) continue; // bad time, or sunset without a location / polar day
            out.push({
                name: p.name,
                temperature: clamp(Math.round(p.temperature), minTemperature, maxTemperature),
                minutes: minutes,
                clock: formatClock(minutes),
                isSunset: p.time === "sunset",
            });
        }
        return out.sort((a, b) => a.minutes - b.minutes);
    }

    // Latest profile that started today; before the first one, yesterday's last.
    readonly property int activeIndex: {
        if (schedule.length === 0) return -1;
        const minutes = now.getHours() * 60 + now.getMinutes();
        let index = schedule.length - 1;
        for (let i = 0; i < schedule.length; i++)
            if (schedule[i].minutes <= minutes) index = i;
        return index;
    }
    readonly property var activeProfile: activeIndex >= 0 ? schedule[activeIndex] : null

    // ---- What is (or should be) on screen ---------------------------------------
    readonly property bool identity: mode === "manual" ? manualNeutral : activeProfile === null
    readonly property int temperature: mode === "manual" ? manualTemperature
                                     : activeProfile ? activeProfile.temperature : neutralTemperature
    readonly property string colorSubtitle: mode === "manual"
        ? `${manualNeutral ? neutralTemperature : manualTemperature} K`
        : activeProfile ? `${activeProfile.name} · ${activeProfile.temperature} K`
        : (configError || "no profiles")
    readonly property string subtitle: Host.glowBrightness && brightness >= 0 ? `${colorSubtitle} · ${brightness}%` : colorSubtitle

    // ---- hyprsunset IPC (debounced) ----------------------------------------------
    // Always (re)send: something else may have changed hyprsunset in between, so
    // skipping "unchanged" values would leave the screen out of sync.
    function refresh() {
        applyDebounce.restart();
    }

    Timer {
        id: applyDebounce
        interval: 50
        onTriggered: {
            // Setting a temperature also turns hyprsunset's identity off; gamma alone does not.
            // hyprsunset gamma stays at 100: dimming goes to the backlight instead.
            const command = service.identity
                ? "hyprctl hyprsunset identity"
                : `hyprctl hyprsunset temperature ${service.temperature} && hyprctl hyprsunset gamma 100`;
            Quickshell.execDetached(["sh", "-c", command + " >/dev/null"]);
        }
    }

    // ---- Backlight (independent of the mode) -----------------------------------------
    // Current backlight %, -1 until the first read. Updated from `light -G` at startup and
    // every second while `watchBacklight` is true (the popup is open), so changes from the
    // brightness keys show up. Set only when the user moves the slider.
    property int brightness: -1
    property bool watchBacklight: false
    property real ignoreReadsUntil: 0 // while dragging, don't let polls pull the slider back

    function setBrightness(p) {
        brightness = Math.round(clamp(p, minBrightness, maxBrightness));
        ignoreReadsUntil = Date.now() + 1000;
        brightnessDebounce.restart();
    }

    Timer {
        id: brightnessDebounce
        interval: 50
        onTriggered: Quickshell.execDetached(["brightnessctl", "-q", "-c", "backlight", "set", `${service.brightness}%`])
    }

    function readBacklight() {
        if (Host.glowBrightness && !backlightReader.running) backlightReader.running = true;
    }

    Process {
        id: backlightReader
        // "apple-panel-bl,backlight,250,50%,500" -> 50
        command: ["brightnessctl", "-m", "-c", "backlight"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = parseFloat((text.split(",")[3] ?? "").replace("%", ""));
                if (Number.isFinite(value) && Date.now() >= service.ignoreReadsUntil)
                    service.brightness = Math.round(value);
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: service.watchBacklight
        triggeredOnStart: true
        onTriggered: service.readBacklight()
    }

    Component.onCompleted: readBacklight()

    // ---- Helpers --------------------------------------------------------------------
    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

    function parseClock(text) {
        const m = /^(\d{1,2}):(\d{2})$/.exec(text);
        if (!m || +m[1] > 23 || +m[2] > 59) return null;
        return +m[1] * 60 + +m[2];
    }

    function formatClock(minutes) {
        const h = Math.floor(minutes / 60) % 24, m = Math.floor(minutes % 60);
        return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
    }

    // Local sunset (minutes after midnight) for `date`, NOAA general solar position
    // with the standard 90.833° zenith. null without a location or on polar day/night.
    function sunsetMinutes(date, latitude, longitude) {
        if (latitude === null || longitude === null) return null;
        const year = date.getFullYear();
        const leap = (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;
        // UTC arithmetic: local dates across a DST change are not whole days apart.
        const dayOfYear = Math.round((Date.UTC(year, date.getMonth(), date.getDate()) - Date.UTC(year, 0, 0)) / 86400000);
        const g = 2 * Math.PI / (leap ? 366 : 365) * (dayOfYear - 1);
        const eqTime = 229.18 * (0.000075 + 0.001868 * Math.cos(g) - 0.032077 * Math.sin(g)
                       - 0.014615 * Math.cos(2 * g) - 0.040849 * Math.sin(2 * g));
        const decl = 0.006918 - 0.399912 * Math.cos(g) + 0.070257 * Math.sin(g) - 0.006758 * Math.cos(2 * g)
                   + 0.000907 * Math.sin(2 * g) - 0.002697 * Math.cos(3 * g) + 0.00148 * Math.sin(3 * g);
        const lat = latitude * Math.PI / 180;
        const x = Math.cos(90.833 * Math.PI / 180) / (Math.cos(lat) * Math.cos(decl)) - Math.tan(lat) * Math.tan(decl);
        if (x < -1 || x > 1) return null;
        const hourAngle = Math.acos(x) * 180 / Math.PI;
        const utcMinutes = 720 - 4 * (longitude - hourAngle) - eqTime;
        const offset = -new Date(year, date.getMonth(), date.getDate(), 12).getTimezoneOffset();
        return Math.round(((utcMinutes + offset) % 1440 + 1440) % 1440);
    }

    // Kelvin -> display colour for the orb and dots (linear between the spec's stops).
    readonly property var colorStops: [
        [1000, 255, 122, 40], [2700, 255, 190, 120], [5500, 255, 244, 230],
        [6500, 255, 255, 255], [10000, 190, 210, 255],
    ]
    function kelvinColor(kelvin) {
        const stops = colorStops;
        const k = clamp(kelvin, stops[0][0], stops[stops.length - 1][0]);
        for (let i = 1; i < stops.length; i++) {
            if (k <= stops[i][0]) {
                const a = stops[i - 1], b = stops[i], t = (k - a[0]) / (b[0] - a[0]);
                return Qt.rgba((a[1] + (b[1] - a[1]) * t) / 255, (a[2] + (b[2] - a[2]) * t) / 255,
                               (a[3] + (b[3] - a[3]) * t) / 255, 1);
            }
        }
        return Qt.rgba(1, 1, 1, 1);
    }
}
