// BatteryService.qml: data for Battery.qml.
//
// - UPower (displayDevice): percentage (0–1 in Quickshell 0.3.0), state, energy (Wh),
//   energyCapacity, changeRate (W), timeToEmpty/timeToFull (s). Live.
// - sysfs /sys/class/power_supply/<batteryName>/ every 10 s: cycle_count, voltage_now,
//   temp, energy_full, energy_full_design. Health = energy_full / energy_full_design
//   (displayDevice is UPower's aggregate device and reports no capacity/health).
// - Apple SMC hwmon every 2 s: total system power and SoC (heatpipe) power, by label.
// - UPower D-Bus (busctl, JSON): GetHistory("charge", 6 h, 72) every 5 min; the charge
//   limit (ChargeThreshold* properties, EnableChargeThreshold; polkit allows the active
//   session without a password).
// - CPU profile: CpuProfileService (shown in the battery panel on the MacBook).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: service

    // ---- Configuration -------------------------------------------------------------------
    property string batteryName: "macsmc-battery"            // ls /sys/class/power_supply
    property string totalPowerLabel: "Total System Power"     // sensors
    property string socPowerLabel: "Heatpipe Power"
    readonly property string sysfs: `/sys/class/power_supply/${batteryName}`
    readonly property string upowerPath: `/org/freedesktop/UPower/devices/battery_${batteryName.replace(/-/g, "_")}`

    // ---- UPower (live) -------------------------------------------------------------------
    readonly property var device: UPower.displayDevice
    readonly property bool present: device?.ready && device?.isLaptopBattery
    readonly property real percent: Math.round((device?.percentage ?? 0) * 100)
    readonly property int state: device?.state ?? UPowerDeviceState.Unknown
    readonly property bool charging: state === UPowerDeviceState.Charging
    readonly property real energy: device?.energy ?? 0
    readonly property real energyFull: device?.energyCapacity ?? 0
    readonly property real draw: Math.abs(device?.changeRate ?? 0)
    readonly property real timeToEmpty: device?.timeToEmpty ?? 0
    readonly property real timeToFull: device?.timeToFull ?? 0

    // ---- sysfs (every 10 s) ----------------------------------------------------------------
    property int cycles: 0
    property real voltage: 0      // V
    property real temperature: NaN // °C
    property real designEnergy: 0 // Wh
    property real fullEnergy: 0   // Wh (current full capacity)
    readonly property real health: designEnergy > 0 ? 100 * fullEnergy / designEnergy : 0

    function readInt(text) { const v = parseInt(text); return Number.isFinite(v) ? v : NaN; }

    FileView { id: cycleFile; path: `${service.sysfs}/cycle_count`; onLoaded: service.cycles = service.readInt(text()) || 0 }
    FileView { id: voltFile; path: `${service.sysfs}/voltage_now`; onLoaded: service.voltage = service.readInt(text()) / 1e6 }
    FileView { id: tempFile; path: `${service.sysfs}/temp`; onLoaded: service.temperature = service.readInt(text()) / 10 }
    FileView { id: designFile; path: `${service.sysfs}/energy_full_design`; onLoaded: service.designEnergy = service.readInt(text()) / 1e6 }
    FileView { id: fullFile; path: `${service.sysfs}/energy_full`; onLoaded: service.fullEnergy = service.readInt(text()) / 1e6 }

    Timer {
        interval: 10000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { cycleFile.reload(); voltFile.reload(); tempFile.reload(); designFile.reload(); fullFile.reload(); }
    }

    // ---- SMC power (every 2 s) ---------------------------------------------------------------
    property real totalPower: NaN
    property real socPower: NaN

    FileView { id: totalFile; path: ""; onLoaded: service.totalPower = service.readInt(text()) / 1e6 }
    FileView { id: socFile; path: ""; onLoaded: service.socPower = service.readInt(text()) / 1e6 }

    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            if (totalFile.path !== "") totalFile.reload();
            if (socFile.path !== "") socFile.reload();
        }
    }

    Process {
        id: powerFinder
        // Prints "<label>\t<path to power*_input>" for both labels.
        command: ["sh", "-c",
            'for f in /sys/class/hwmon/hwmon*/power*_label; do l=$(cat "$f"); '
            + 'if [ "$l" = "$1" ] || [ "$l" = "$2" ]; then printf "%s\\t%s\\n" "$l" "${f%_label}_input"; fi; done',
            "sh", service.totalPowerLabel, service.socPowerLabel]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.trim().split("\n")) {
                    const [label, path] = line.split("\t");
                    if (label === service.totalPowerLabel) totalFile.path = path;
                    if (label === service.socPowerLabel) socFile.path = path;
                }
            }
        }
    }

    // ---- Charge history (every 5 min) -----------------------------------------------------
    // [{ t: unix s, v: %, state: UPower state }] oldest first.
    property var history: []

    function readHistory() { if (!historyReader.running) historyReader.running = true; }

    Timer { interval: 5 * 60 * 1000; running: true; repeat: true; onTriggered: service.readHistory() }

    Process {
        id: historyReader
        command: ["busctl", "--system", "--json=short", "call", "org.freedesktop.UPower", service.upowerPath,
                  "org.freedesktop.UPower.Device", "GetHistory", "suu", "charge", "21600", "72"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const rows = JSON.parse(text).data[0];
                    service.history = rows.map(r => ({ t: r[0], v: r[1], state: r[2] }))
                                          .filter(r => r.t > 0).sort((a, b) => a.t - b.t);
                } catch (e) {}
            }
        }
    }

    // ---- Charge limit -------------------------------------------------------------------------
    property bool limitSupported: false
    property bool limitEnabled: false
    property int limitStart: 75
    property int limitEnd: 80

    function readLimit() { if (!limitReader.running) limitReader.running = true; }

    Process {
        id: limitReader
        command: ["busctl", "--system", "--json=short", "get-property", "org.freedesktop.UPower", service.upowerPath,
                  "org.freedesktop.UPower.Device", "ChargeThresholdSupported", "ChargeThresholdEnabled",
                  "ChargeStartThreshold", "ChargeEndThreshold"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim().split("\n").map(l => { try { return JSON.parse(l).data; } catch (e) { return null; } });
                if (v.length < 4) return;
                service.limitSupported = v[0] === true;
                service.limitEnabled = v[1] === true;
                service.limitStart = v[2] ?? 75;
                service.limitEnd = v[3] ?? 80;
            }
        }
    }

    function setLimit(on) {
        limitEnabled = on; // optimistic; re-read confirms
        limitWriter.command = ["busctl", "--system", "call", "org.freedesktop.UPower", upowerPath,
                               "org.freedesktop.UPower.Device", "EnableChargeThreshold", "b", on ? "true" : "false"];
        limitWriter.running = true;
    }

    Process {
        id: limitWriter
        onExited: service.readLimit()
    }

    // ---- Refresh -----------------------------------------------------------------------------------
    function refreshAll() { readHistory(); readLimit(); CpuProfileService.readProfile(); }
    Component.onCompleted: { powerFinder.running = true; refreshAll(); }

    // ---- Formatting --------------------------------------------------------------------------------
    // 30780 -> "8 h 33 min"
    function duration(seconds) {
        if (!(seconds > 0)) return "";
        const h = Math.floor(seconds / 3600), m = Math.round((seconds % 3600) / 60);
        return h > 0 ? `${h} h ${m} min` : `${m} min`;
    }

    readonly property string stateLine: {
        if (!present) return "No battery";
        if (state === UPowerDeviceState.Charging) return "Charging";
        if (state === UPowerDeviceState.PendingCharge) return `Held at ${percent}%`;
        if (state === UPowerDeviceState.FullyCharged) return "Fully charged";
        if (percent <= 10) return "Battery low";
        return "On battery";
    }

    readonly property string timeLine: charging
        ? (timeToFull > 0 ? `${duration(timeToFull)} until ${limitEnabled ? limitEnd : 100}%` : "")
        : (state === UPowerDeviceState.Discharging && timeToEmpty > 0 ? `${duration(timeToEmpty)} left` : "")

    // Chip / icon colour.
    readonly property color levelColor: charging ? Theme.accent
                                      : percent <= 10 ? Theme.error
                                      : percent <= 20 ? Theme.warning
                                      : Theme.accent
}
