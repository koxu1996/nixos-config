// StatsService.qml: resource sampling for SystemStats (chip + panel).
//
// Every second: CPU total + per core (/proc/stat deltas), memory (MemTotal - MemAvailable,
// /proc/meminfo) and a temperature sensor picked by its hwmon label. 300-sample ring
// buffers (5 min) shared by the chip sparklines and the panel charts. Disk: `df -B1 /`
// every 60 s.
//
// The machine (core layout, temperature and power sensor labels) comes from Host.qml
// (my.look.machine in the host's config).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: service

    // ---- Configuration ------------------------------------------------------------------
    // Per machine (my.look.machine -> Host.qml).
    property string tempLabel: Host.tempLabel
    property int tempWarm: Host.tempWarm         // °C: "warm" from here
    property int tempThrottle: Host.tempThrottle // °C: "throttling"
    property string powerLabel: Host.powerLabel  // "" = no power chart
    property real powerMax: 25       // W, top of the power chart
    readonly property int historyLength: 300
    readonly property var eCores: Host.eCores

    // ---- State ----------------------------------------------------------------------------
    property var cpuHistory: []   // total CPU %, oldest first
    property var memHistory: []   // used GiB
    property var tempHistory: []  // °C
    property var powerHistory: [] // W
    property var coreLoads: []    // current % per core (cpu0..)
    readonly property real cpu: cpuHistory.length ? cpuHistory[cpuHistory.length - 1] : 0
    readonly property real memUsed: memHistory.length ? memHistory[memHistory.length - 1] : 0
    readonly property real temp: tempHistory.length ? tempHistory[tempHistory.length - 1] : NaN
    readonly property real power: powerHistory.length ? powerHistory[powerHistory.length - 1] : NaN
    property real memTotal: 0     // GiB (kernel-visible)
    readonly property int memInstalled: Math.ceil(memTotal / 8) * 8 // marketed size, e.g. 24
    property real diskUsed: 0     // bytes
    property real diskSize: 0
    property real diskAvail: 0

    // Panel charts only repaint while this is true (set by the panel).
    property bool panelOpen: false
    signal sampled()

    // ---- Sampling -------------------------------------------------------------------------
    property var lastCpuTimes: [] // [[busy, total] per line: cpu, cpu0, cpu1, ...]

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statFile.reload();
            memFile.reload();
            if (tempFile.path !== "") tempFile.reload();
            if (powerFile.path !== "") powerFile.reload();
        }
    }

    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: service.parseStat(text())
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: service.parseMem(text())
    }

    FileView {
        id: tempFile
        path: ""
        onLoaded: {
            const v = parseInt(text()) / 1000;
            if (Number.isFinite(v)) service.tempHistory = service.pushed(service.tempHistory, v);
        }
    }

    FileView {
        id: powerFile
        path: ""
        onLoaded: {
            const w = parseInt(text()) / 1e6;
            if (Number.isFinite(w)) service.powerHistory = service.pushed(service.powerHistory, w);
        }
    }

    function pushed(list, value) {
        const next = list.length >= historyLength ? list.slice(list.length - historyLength + 1) : list.slice();
        next.push(value);
        return next;
    }

    function parseStat(text) {
        const times = [];
        for (const line of text.split("\n")) {
            if (!line.startsWith("cpu")) break;
            const f = line.trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + (f[4] || 0);                      // idle + iowait
            const total = f.slice(0, 8).reduce((a, b) => a + b, 0); // up to steal
            times.push([total - idle, total]);
        }
        if (lastCpuTimes.length === times.length) {
            const loads = times.map((t, i) => {
                const dTotal = t[1] - lastCpuTimes[i][1];
                return dTotal > 0 ? Math.max(0, Math.min(100, 100 * (t[0] - lastCpuTimes[i][0]) / dTotal)) : 0;
            });
            cpuHistory = pushed(cpuHistory, loads[0]);
            coreLoads = loads.slice(1);
            sampled();
        }
        lastCpuTimes = times;
    }

    function parseMem(text) {
        const kb = key => {
            const m = new RegExp(`^${key}:\\s+(\\d+)`, "m").exec(text);
            return m ? +m[1] : 0;
        };
        const total = kb("MemTotal"), available = kb("MemAvailable");
        if (total <= 0) return;
        memTotal = total / 1048576;
        memHistory = pushed(memHistory, (total - available) / 1048576);
    }

    // Find the hwmon temp*_input whose temp*_label matches `tempLabel`.
    onTempLabelChanged: findSensor()
    onPowerLabelChanged: findPowerSensor()
    Component.onCompleted: { findSensor(); findPowerSensor(); readDisk(); }

    // Same lookup for the power*_input whose power*_label matches `powerLabel`.
    function findPowerSensor() {
        powerHistory = [];
        powerFile.path = "";
        if (powerLabel === "") return;
        powerFinder.command = ["sh", "-c",
            'for f in /sys/class/hwmon/hwmon*/power*_label; do [ "$(cat "$f")" = "$1" ] && { echo "${f%_label}_input"; break; }; done',
            "sh", powerLabel];
        powerFinder.running = true;
    }

    Process {
        id: powerFinder
        stdout: StdioCollector {
            onStreamFinished: powerFile.path = text.trim()
        }
    }

    readonly property bool hasPower: powerFile.path !== ""

    function findSensor() {
        tempHistory = [];
        tempFile.path = "";
        sensorFinder.command = ["sh", "-c",
            'for f in /sys/class/hwmon/hwmon*/temp*_label; do [ "$(cat "$f")" = "$1" ] && { echo "${f%_label}_input"; break; }; done',
            "sh", tempLabel];
        sensorFinder.running = true;
    }

    Process {
        id: sensorFinder
        stdout: StdioCollector {
            onStreamFinished: tempFile.path = text.trim()
        }
    }

    readonly property bool hasTemp: tempFile.path !== ""

    // ---- Disk (every 60 s) ---------------------------------------------------------------
    Timer {
        interval: 60 * 1000
        running: true
        repeat: true
        onTriggered: service.readDisk()
    }

    function readDisk() { if (!diskReader.running) diskReader.running = true; }

    Process {
        id: diskReader
        command: ["df", "-B1", "--output=size,used,avail", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split("\n").pop().trim().split(/\s+/).map(Number);
                if (f.length === 3 && f.every(Number.isFinite)) {
                    service.diskSize = f[0];
                    service.diskUsed = f[1];
                    service.diskAvail = f[2];
                }
            }
        }
    }

    // ---- Formatting -------------------------------------------------------------------------
    function bytes(b) {
        return b >= 1e12 ? `${(b / 1e12).toFixed(2)} TB` : `${Math.round(b / 1e9)} GB`;
    }

    // "2m 14s ago" for a sample `n` seconds old.
    function ago(seconds) {
        if (seconds <= 0) return "now";
        const m = Math.floor(seconds / 60), s = seconds % 60;
        return m > 0 ? `${m}m ${s}s ago` : `${s}s ago`;
    }

    function tempStatus(t) {
        if (!Number.isFinite(t)) return "unknown";
        return t >= tempThrottle ? "throttling" : t >= tempWarm ? "warm" : "normal";
    }
}
