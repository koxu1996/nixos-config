// ClockService.qml: shared time, date helpers and time zone lookups for the clock.
//
// - Time comes from SystemClock: minute precision normally, seconds while `precise` is
//   true (the popup is open).
// - Names are English and fixed here (independent of the system locale); 24-hour time;
//   weeks start on Monday; ISO week numbers.
// - Extra zones come from ~/.config/quickshell/clock/config.json. QML's JS engine
//   ignores the `timeZone` option of toLocaleString and has no Intl, so zone times are
//   read with one small `TZ=<zone> date` process per minute (correct across DST).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: service

    // ---- Time -------------------------------------------------------------------------
    property bool precise: false

    SystemClock {
        id: clock
        precision: service.precise ? SystemClock.Seconds : SystemClock.Minutes
    }

    readonly property date now: clock.date

    readonly property var dayNames: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    readonly property var dayShort: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"]
    readonly property var monthShort: ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    function pad2(n) { return String(n).padStart(2, "0"); }
    function weekdayIndex(d) { return (d.getDay() + 6) % 7; } // Monday = 0

    readonly property string timeText: `${pad2(now.getHours())}:${pad2(now.getMinutes())}`
    readonly property string secondsText: `:${pad2(now.getSeconds())}`
    readonly property string shortDate: `${dayShort[weekdayIndex(now)]} ${now.getDate()} ${monthShort[now.getMonth()]}`
    readonly property string longDate:
        `${dayNames[weekdayIndex(now)]}, ${now.getDate()} ${monthNames[now.getMonth()]} ${now.getFullYear()}`
    readonly property string weekLine:
        `week ${isoWeek(now)} · day ${dayOfYear(now)} of ${daysInYear(now.getFullYear())}`

    // ---- Date helpers -------------------------------------------------------------------
    function isLeap(y) { return (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0; }
    function daysInYear(y) { return isLeap(y) ? 366 : 365; }

    // UTC arithmetic so DST changes don't shift day counts.
    function dayOfYear(d) {
        return Math.round((Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()) - Date.UTC(d.getFullYear(), 0, 1)) / 86400000) + 1;
    }

    // ISO 8601 week: the week with the year's first Thursday is week 1.
    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        t.setUTCDate(t.getUTCDate() + 3 - (t.getUTCDay() + 6) % 7); // Thursday of this week
        const firstThursday = new Date(Date.UTC(t.getUTCFullYear(), 0, 4));
        return 1 + Math.round(((t - firstThursday) / 86400000 - 3 + (firstThursday.getUTCDay() + 6) % 7) / 7);
    }

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    // Always 42 cells (6 weeks, Monday first) so the calendar height never changes.
    function monthGrid(year, month) {
        const first = new Date(year, month, 1);
        const start = new Date(year, month, 1 - weekdayIndex(first));
        const cells = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
            cells.push({
                day: d.getDate(),
                inMonth: d.getMonth() === month,
                weekend: weekdayIndex(d) >= 5,
                today: sameDay(d, now),
            });
        }
        return cells;
    }

    // ---- Time zones -----------------------------------------------------------------------
    readonly property string configPath:
        (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/quickshell/clock/config.json"

    property var zones: []      // [{ name, tz }] from the config
    property var zoneTimes: []  // [{ name, time, offset }] for display
    property string configError: ""

    FileView {
        path: service.configPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: service.parseConfig(text())
        onLoadFailed: error => { service.zones = []; service.configError = `cannot read ${service.configPath}`; }
    }

    function parseConfig(text) {
        try {
            const json = JSON.parse(text);
            const list = Array.isArray(json) ? json : (json.zones ?? []);
            zones = list.filter(z => typeof z.name === "string" && typeof z.tz === "string");
            configError = "";
        } catch (e) {
            zones = [];
            configError = `invalid JSON in ${configPath}`;
        }
        readZones();
    }

    // Refresh zone times when the minute changes (not every second while precise).
    readonly property int minuteKey: now.getHours() * 60 + now.getMinutes()
    onMinuteKeyChanged: readZones()

    function readZones() {
        if (zones.length === 0) { zoneTimes = []; return; }
        if (zoneReader.running) return;
        // One line per zone: "<offset> <HH:MM>", or "invalid"; last line: local offset.
        const script = 'for z do if [ -e "${TZDIR:-/usr/share/zoneinfo}/$z" ]; then TZ="$z" date "+%z %H:%M"; '
                     + 'else echo invalid; fi; done; date +%z';
        zoneReader.command = ["sh", "-c", script, "sh"].concat(zones.map(z => z.tz));
        zoneReader.running = true;
    }

    Process {
        id: zoneReader
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const local = service.offsetMinutes(lines[lines.length - 1]);
                service.zoneTimes = service.zones.map((z, i) => {
                    const parts = (lines[i] ?? "invalid").split(" ");
                    if (parts[0] === "invalid" || parts.length < 2)
                        return { name: z.name, time: "--:--", offset: "unknown zone" };
                    return { name: z.name, time: parts[1], offset: service.formatOffset(service.offsetMinutes(parts[0]) - local) };
                });
            }
        }
    }

    // "+0530" -> 330
    function offsetMinutes(z) {
        const m = /^([+-])(\d{2})(\d{2})$/.exec(z.trim());
        if (!m) return 0;
        return (m[1] === "-" ? -1 : 1) * (+m[2] * 60 + +m[3]);
    }

    // Relative to local time: "same", "+3h", "−6h" (true minus), "+5:30h".
    function formatOffset(minutes) {
        if (minutes === 0) return "same";
        const sign = minutes > 0 ? "+" : "−";
        const abs = Math.abs(minutes), h = Math.floor(abs / 60), m = abs % 60;
        return m === 0 ? `${sign}${h}h` : `${sign}${h}:${pad2(m)}h`;
    }
}
