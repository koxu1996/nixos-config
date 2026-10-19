// Not used (hyprpaper is the wallpaper). To enable: add `Wallpaper {}` to shell.qml and
// compile the shader: qsb --qt6 -o waves.frag.qsb waves.frag (qt6.qtshadertools).
//
// Wallpaper.qml: live "waves" wallpaper (waves.frag → waves.frag.qsb) on the background
// layer of every screen. Cheap on a fanless laptop: 30 fps on
// battery (60 on the charger), and fully paused (no redraws) while the screen's active
// workspace has windows. Heat (SoC/board temperature) warms the palette and speeds the
// waves; the workspace number adds a parallax offset.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland

Scope {
    id: root

    // ---- Settings -----------------------------------------------------------------------
    // hwmon temp*_input to drive `heat`. Empty = look it up by `tempLabel` (hwmon numbers
    // can change between boots). Asahi exposes no SoC die temperature on the M2; the
    // WiFi/BT module sensor reacts fastest to CPU load (see StatsService).
    property string tempPath: ""
    property string tempLabel: "WiFi/BT Module Temp"
    property real coolTemp: 45
    property real hotTemp: 90
    property bool pauseWhenCovered: true
    property real parallaxPerWorkspace: 0.35  // waves shift per workspace number (0 = off)
    property real speed: 0.4             // flow speed (1 = the original pace)
    property real softness: 14           // shader `soft`: blurs wave edges/glows, same brightness
    property int resolutionDivisor: 1    // >1 renders at 1/n size and scales up (cheaper, pixelated)

    // ---- Shared inputs ------------------------------------------------------------------------
    readonly property bool onBattery: UPower.onBattery
    property real tempC: NaN
    readonly property string resolvedTempPath: tempPath !== "" ? tempPath : foundTempPath
    property string foundTempPath: ""

    Process {
        running: root.tempPath === ""
        command: ["sh", "-c",
            'for f in /sys/class/hwmon/hwmon*/temp*_label; do [ "$(cat "$f")" = "$1" ] && { echo "${f%_label}_input"; break; }; done',
            "sh", root.tempLabel]
        stdout: StdioCollector { onStreamFinished: root.foundTempPath = text.trim() }
    }

    FileView {
        id: tempFile
        path: root.resolvedTempPath
        onLoaded: {
            const v = parseInt(text()) / 1000;
            if (Number.isFinite(v)) root.tempC = v;
        }
    }

    Timer {
        interval: 2000
        running: root.resolvedTempPath !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: tempFile.reload()
    }

    readonly property real heat: Number.isFinite(tempC)
        ? Math.max(0, Math.min(1, (tempC - coolTemp) / (hotTemp - coolTemp))) : 0

    // ---- One wallpaper per screen ---------------------------------------------------------------
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window

            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "waves-wallpaper"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "#08090f"

            readonly property var workspace: Hyprland.monitorFor(modelData)?.activeWorkspace ?? null
            readonly property bool covered: (workspace?.toplevels.values.length ?? 0) > 0
            readonly property bool paused: root.pauseWhenCovered && covered

            property real time: 0

            Timer {
                id: clock
                interval: root.onBattery ? 33 : 16
                running: !window.paused
                repeat: true
                onTriggered: window.time += interval / 1000 * root.speed * (root.onBattery ? 0.7 : 1) * (1 + shader.heat * 1.4)
            }

            // With resolutionDivisor > 1 the shader draws into a texture at 1/n size, which is
            // then scaled up (smooth) to the full window; at 1 it renders directly.
            Item {
                anchors.fill: parent
                layer.enabled: root.resolutionDivisor > 1
                layer.smooth: true
                layer.textureSize: Qt.size(width / root.resolutionDivisor, height / root.resolutionDivisor)

                ShaderEffect {
                    id: shader
                    anchors.fill: parent
                    fragmentShader: Qt.resolvedUrl("waves.frag.qsb")

                    property real time: window.time
                    property vector2d res: Qt.vector2d(width, height)
                    // Edge blur factor (wave edges and rim glow widen by `soft`; the rim's
                    // strength is divided by it, so the scene doesn't brighten).
                    property real soft: root.softness

                    property real heat: root.heat
                    Behavior on heat { NumberAnimation { duration: 3000; easing.type: Easing.InOutQuad } }

                    property real offset: ((window.workspace?.id ?? 1) - 1) * root.parallaxPerWorkspace
                    Behavior on offset { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }

                    property real energy: root.onBattery ? 0.82 : 1.0
                    Behavior on energy { NumberAnimation { duration: 800 } }
                }
            }
        }
    }
}
