// Volume.qml: MacBook Air (J413, Asahi) audio for the Quickshell bar.
// Output: only the DSP speaker sink ("MacBook Air J413 Speakers",
// node audio_effect.j413-convolver), never the raw ALSA speaker output.
// Input: the default audio source (microphone), switchable in the popover.
// Checked against Quickshell 0.3.0. Use it as `Volume {}` inside the bar's PanelWindow.
// Colours, radii, fonts and timings come from Theme.qml.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

Item {
    id: root

    // ---- Sink --------------------------------------------------------------
    // The raw speaker output must never be driven directly (no DSP, no limiter).
    function isRawSpeaker(node) {
        const text = `${node.name} ${node.description} ${node.nickname}`;
        return node.name.startsWith("alsa_output.") && /speaker|j413|pro-output/i.test(text);
    }

    readonly property PwNode dspSink: {
        for (const node of Pipewire.nodes.values) {
            if (node.audio && node.isSink && !node.isStream
                    && node.description.includes("J413") && !isRawSpeaker(node))
                return node;
        }
        return null;
    }

    readonly property PwNode sink: {
        if (dspSink) return dspSink;
        const fallback = Pipewire.defaultAudioSink;
        return fallback && !isRawSpeaker(fallback) ? fallback : null;
    }

    readonly property bool isDsp: sink !== null && sink === dspSink

    // ---- Source (microphone) ---------------------------------------------------
    readonly property var sources: Pipewire.nodes.values.filter(
        node => node.audio && !node.isSink && !node.isStream)

    // The default source, or the first one when PipeWire has no default yet.
    readonly property PwNode source: Pipewire.defaultAudioSource
        ?? (sources.length > 0 ? sources[0] : null)

    readonly property bool sourceAvailable: source?.audio != null
    readonly property real sourceVolume: sourceAvailable
        ? Math.max(0, Math.min(1, source.audio.volume)) : 0
    readonly property bool sourceMuted: sourceAvailable && source.audio.muted

    function setSourceVolume(v, unmute) {
        if (!sourceAvailable) return;
        const clamped = Math.max(0, Math.min(1, v));
        source.audio.volume = clamped;
        if (unmute && clamped > 0 && source.audio.muted) source.audio.muted = false;
    }

    function toggleSourceMute() {
        if (sourceAvailable) source.audio.muted = !source.audio.muted;
    }

    function selectSource(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }

    function sourceLabel(node) {
        return node?.description || node?.nickname || node?.name || "";
    }

    // Binds the sink and source so audio.volume / audio.muted are live.
    PwObjectTracker {
        objects: [root.sink, root.source].filter(node => node !== null)
    }

    readonly property bool available: sink?.audio != null
    readonly property real volume: available ? Math.max(0, Math.min(1, sink.audio.volume)) : 0
    readonly property bool muted: available && sink.audio.muted
    readonly property bool silent: !available || muted || volume <= 0.001
    readonly property int percent: Math.round(volume * 100)
    // 0, 1 or 2 sound waves; -1 = speaker with a cross.
    readonly property int waves: silent ? -1 : volume < 0.34 ? 0 : volume < 0.67 ? 1 : 2

    function setVolume(v, unmute) {
        if (!available) return;
        const clamped = Math.max(0, Math.min(1, v)); // no over-amplification
        sink.audio.volume = clamped;
        if (unmute && clamped > 0 && sink.audio.muted) sink.audio.muted = false;
    }

    function stepVolume(delta) {
        setVolume(Math.round((volume + delta) * 20) / 20, false);
    }

    function toggleMute() {
        if (available) sink.audio.muted = !sink.audio.muted;
    }

    // ---- OSD trigger -------------------------------------------------------
    // Shows on volume/mute changes made while the popover is closed (scroll,
    // media keys, other apps), but not for middle-click or the first sync.
    property bool osdArmed: false
    property real suppressOsdUntil: 0

    onSinkChanged: { osdArmed = false; armOsd.restart(); }
    Timer { id: armOsd; interval: 800; running: true; onTriggered: root.osdArmed = true }

    function maybeShowOsd() {
        if (!osdArmed || popover.open || Date.now() < suppressOsdUntil) return;
        osd.show();
    }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumesChanged() { root.maybeShowOsd(); }
        function onMutedChanged() { root.maybeShowOsd(); }
    }

    // ---- Chip --------------------------------------------------------------
    implicitWidth: chip.implicitWidth
    implicitHeight: chip.implicitHeight

    Rectangle {
        id: chip

        readonly property color fg: root.silent ? Theme.textDisabled : Theme.accent

        implicitWidth: chipRow.implicitWidth + Theme.barChipPadding * 2
        implicitHeight: Theme.barChipHeight
        radius: Theme.radiusSmall
        color: chipMouse.containsMouse || popover.open ? Theme.chipHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 7

            SpeakerIcon {
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.barIconSize
                waves: root.waves
                color: chip.fg
            }

        }

        TextMetrics {
            id: muteMetrics
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontSize
            text: "100%"
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton

            property real wheelAccum: 0

            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton) {
                    root.suppressOsdUntil = Date.now() + 400;
                    root.toggleMute();
                } else {
                    popover.toggle();
                }
            }

            onWheel: wheel => {
                wheelAccum += wheel.angleDelta.y;
                while (Math.abs(wheelAccum) >= 120) {
                    root.stepVolume(wheelAccum > 0 ? 0.05 : -0.05);
                    wheelAccum -= wheelAccum > 0 ? 120 : -120;
                }
            }
        }
    }

    // ---- Popover -----------------------------------------------------------
    PopupWindow {
        id: popover

        property bool open: false

        function toggle() { if (open) close(); else if (!PopupManager.justClosed("volume")) show(); }
        function show() { PopupManager.opened("volume"); visible = true; fadeInDelay.restart(); }
        function close() { fadeInDelay.stop(); open = false; PopupManager.closed("volume"); hideAfterFade.restart(); }

        // Only one bar popup at a time (PopupManager).
        Connections {
            target: PopupManager
            function onCurrentChanged() { if (popover.visible && PopupManager.current !== "volume") popover.close(); }
        }

        anchor.item: chip
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.bottom: -Theme.popupGap // margins resize the anchor rect; negative = below it

        implicitWidth: 300
        implicitHeight: card.implicitHeight
        color: "transparent"
        visible: false

        // Map the window with the card still transparent and start the fade-in a frame
        // later, so the window's very first frame shows nothing (no stale-frame flash).
        Timer { id: fadeInDelay; interval: 16; onTriggered: { popover.open = true; card.forceActiveFocus(); } }

        Timer { id: hideAfterFade; interval: Theme.durationNormal; onTriggered: if (!popover.open) popover.visible = false }

        // Keyboard focus for Escape, and click-outside detection without
        // closing instantly (so the fade-out still plays).
        HyprlandFocusGrab {
            windows: [popover]
            active: popover.visible
            onCleared: popover.close()
        }

        Rectangle {
            id: card

            width: parent.width
            implicitHeight: content.implicitHeight + 28
            radius: Theme.radiusLarge
            color: Theme.raised
            border.width: Theme.borderWidth
            border.color: Theme.border

            focus: true
            Keys.onEscapePressed: popover.close()

            transformOrigin: Item.TopRight
            opacity: popover.open ? 1 : 0
            scale: popover.open ? 1 : 0.94
            Behavior on opacity { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }

            Column {
                id: content
                x: 14
                y: 14
                width: parent.width - 28
                spacing: 14

                // Header.
                Row {
                    spacing: 10

                    Rectangle {
                        width: 34
                        height: 34
                        radius: Theme.radiusSmall
                        color: Theme.accentBg

                        SvgIcon {
                            anchors.centerIn: parent
                            size: 18
                            color: Theme.accent
                            path: "M20 16V7A2 2 0 0 0 18 5H6A2 2 0 0 0 4 7V16 M20 16H4 "
                                + "M20 16L21.28 18.55A1 1 0 0 1 20.38 20H3.62A1 1 0 0 1 2.72 18.55L4 16"
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: root.isDsp ? "MacBook Air Speakers" : (root.sink?.description || "No speaker sink")
                            color: Theme.textPrimary
                            font.family: Theme.sansFont
                            font.pixelSize: Theme.fontSizeTitle
                        }

                        Text {
                            text: root.isDsp ? "J413 DSP · PipeWire sink" : "fallback · PipeWire sink"
                            color: Theme.textDisabled
                            font.family: Theme.monoFont
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }

                // Output: mute toggle, slider, value.
                LevelRow {
                    width: parent.width
                    value: root.volume
                    muted: root.muted
                    waves: root.waves
                    onMoved: v => root.setVolume(v, true)
                    onStepped: d => root.stepVolume(d)
                    onMuteToggled: root.toggleMute()
                }

                // Presets.
                Row {
                    id: presets
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: [0, 25, 50, 75, 100]

                        delegate: Rectangle {
                            id: preset
                            required property int modelData
                            readonly property bool current: !root.muted && root.percent === modelData

                            width: (presets.width - presets.spacing * 4) / 5
                            height: Theme.barItemHeight
                            radius: Theme.radiusSmall
                            color: current ? Theme.accentBg
                                 : presetMouse.containsMouse ? Theme.track : Theme.inset

                            Text {
                                anchors.centerIn: parent
                                text: preset.modelData
                                color: preset.current ? Theme.accent : Theme.textSecondary
                                font.family: Theme.monoFont
                                font.pixelSize: Theme.fontSize
                                font.features: { "tnum": 1 }
                            }

                            MouseArea {
                                id: presetMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setVolume(preset.modelData / 100, true)
                            }
                        }
                    }
                }

                // ---- Input ----
                Rectangle {
                    width: parent.width
                    height: Theme.borderWidth
                    color: Theme.border
                }

                Row {
                    width: parent.width
                    spacing: 8

                    Text {
                        id: inputLabel
                        text: "Input"
                        color: Theme.textSecondary
                        font.family: Theme.sansFont
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        width: parent.width - inputLabel.width - parent.spacing
                        anchors.baseline: inputLabel.baseline
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        text: root.source ? root.sourceLabel(root.source) : "No input device"
                        color: root.source ? Theme.textSecondary : Theme.textDisabled
                        font.family: Theme.monoFont
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }

                // Device picker, only when there is something to choose.
                Column {
                    width: parent.width
                    spacing: 4
                    visible: root.sources.length > 1

                    Repeater {
                        model: root.sources

                        delegate: Rectangle {
                            id: device
                            required property var modelData
                            readonly property bool current: modelData === root.source

                            width: parent.width
                            height: Theme.barItemHeight
                            radius: Theme.radiusSmall
                            color: current ? Theme.accentBg
                                 : deviceMouse.containsMouse ? Theme.track : Theme.inset

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 10
                                width: parent.width - 20
                                elide: Text.ElideRight
                                text: root.sourceLabel(device.modelData)
                                color: device.current ? Theme.accent : Theme.textSecondary
                                font.family: Theme.sansFont
                                font.pixelSize: Theme.fontSize
                            }

                            MouseArea {
                                id: deviceMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectSource(device.modelData)
                            }
                        }
                    }
                }

                LevelRow {
                    width: parent.width
                    visible: root.sourceAvailable
                    mic: true
                    value: root.sourceVolume
                    muted: root.sourceMuted
                    onMoved: v => root.setSourceVolume(v, true)
                    onStepped: d => root.setSourceVolume(Math.round((root.sourceVolume + d) * 20) / 20, false)
                    onMuteToggled: root.toggleSourceMute()
                }
            }
        }
    }

    // ---- OSD ---------------------------------------------------------------
    PanelWindow {
        id: osd

        property bool shown: false

        function show() {
            visible = true;
            shown = true;
            osdTimer.restart();
        }

        screen: root.QsWindow.window?.screen ?? null
        anchors.bottom: true
        margins.bottom: 90
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: osdPill.implicitWidth
        implicitHeight: osdPill.implicitHeight
        color: "transparent"
        mask: Region {} // never takes input
        visible: false

        Timer { id: osdTimer; interval: 1100; onTriggered: osd.shown = false }
        Timer { id: osdHide; interval: Theme.durationNormal; onTriggered: if (!osd.shown) osd.visible = false }
        onShownChanged: if (!shown) osdHide.restart()

        Rectangle {
            id: osdPill

            implicitWidth: osdRow.implicitWidth + 32
            implicitHeight: 40
            radius: height / 2
            color: Theme.raised
            border.width: Theme.borderWidth
            border.color: Theme.border

            opacity: osd.shown ? 1 : 0
            scale: osd.shown ? 1 : 0.94
            Behavior on opacity { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }

            Row {
                id: osdRow
                anchors.centerIn: parent
                spacing: 12

                SpeakerIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    waves: root.waves
                    color: root.silent ? Theme.textDisabled : Theme.accent
                }

                MiniBar {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 140
                    height: 4
                    value: root.volume
                    dim: root.silent
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: muteMetrics.width
                    horizontalAlignment: Text.AlignRight
                    text: root.muted ? "mute" : root.percent + "%"
                    color: root.silent ? Theme.textDisabled : Theme.textPrimary
                    font.family: Theme.monoFont
                    font.pixelSize: Theme.fontSize
                    font.features: { "tnum": 1 }
                }
            }
        }
    }

    // ---- Pieces ------------------------------------------------------------
    // Mute toggle + slider + value, for the speakers or (mic: true) a microphone.
    component LevelRow: Row {
        id: level

        property real value: 0
        property bool muted: false
        property bool mic: false
        property int waves: 1 // speaker icon only

        signal moved(real value)
        signal stepped(real delta)
        signal muteToggled()

        spacing: 10

        Rectangle {
            id: levelMute
            width: 30
            height: 30
            radius: Theme.radiusSmall
            anchors.verticalCenter: parent.verticalCenter
            color: level.muted ? Theme.alpha(Theme.error, 0.15)
                 : levelMuteMouse.containsMouse ? Theme.track : Theme.inset

            SpeakerIcon {
                anchors.centerIn: parent
                visible: !level.mic
                waves: level.muted ? -1 : Math.max(level.waves, 0)
                color: level.muted ? Theme.error : Theme.accent
            }

            MicIcon {
                anchors.centerIn: parent
                visible: level.mic
                off: level.muted
                color: level.muted ? Theme.error : Theme.accent
            }

            MouseArea {
                id: levelMuteMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: level.muteToggled()
            }
        }

        Item {
            id: levelSlider
            width: level.width - levelMute.width - levelValue.width - level.spacing * 2
            height: 30
            anchors.verticalCenter: parent.verticalCenter

            readonly property real handleSize: 14
            readonly property real usable: width - handleSize

            Rectangle {
                id: levelTrack
                x: levelSlider.handleSize / 2
                width: levelSlider.usable
                height: 6
                radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.track

                Rectangle {
                    width: Math.max(height, levelTrack.width * level.value)
                    height: parent.height
                    radius: 3
                    visible: level.value > 0
                    opacity: level.muted ? 0.35 : 1
                    gradient: AccentGradient {}
                }
            }

            Rectangle {
                width: levelSlider.handleSize
                height: levelSlider.handleSize
                radius: width / 2
                x: levelSlider.usable * level.value
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.textPrimary
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                function apply(mx) {
                    level.moved((mx - levelSlider.handleSize / 2) / levelSlider.usable);
                }
                onPressed: mouse => apply(mouse.x)
                onPositionChanged: mouse => { if (pressed) apply(mouse.x); }
                onWheel: wheel => level.stepped(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
            }
        }

        Text {
            id: levelValue
            width: muteMetrics.width
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: Math.round(level.value * 100) + "%"
            color: level.muted ? Theme.textDisabled : Theme.textPrimary
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontSize
            font.features: { "tnum": 1 }
        }
    }

    // Microphone, crossed out when `off`.
    component MicIcon: SvgIcon {
        property bool off: false

        size: Theme.iconSize
        path: "M12 2A3 3 0 0 0 9 5V12A3 3 0 0 0 15 12V5A3 3 0 0 0 12 2Z "
            + "M19 10V12A7 7 0 0 1 5 12V10 M12 19V22"
            + (off ? " M3 3L21 21" : "")
    }

    // Thin level bar with the accent gradient (all dim when silent).
    component MiniBar: Rectangle {
        id: bar
        property real value: 0
        property bool dim: false

        radius: height / 2
        color: Theme.track

        Rectangle {
            width: bar.width * Math.max(0, Math.min(1, bar.value))
            height: bar.height
            radius: bar.radius
            visible: width > 0
            color: Theme.textDisabled
            gradient: bar.dim ? null : fillGradient

            AccentGradient { id: fillGradient }
        }
    }

    // Speaker with 0/1/2 waves, or with a cross when waves < 0.
    component SpeakerIcon: SvgIcon {
        property int waves: 0

        size: Theme.iconSize
        path: "M11 5L6 9H2V15H6L11 19Z "
            + (waves < 0 ? "M22 9L16 15 M16 9L22 15"
               : (waves >= 1 ? "M15.54 8.46A5 5 0 0 1 15.54 15.54 " : "")
                 + (waves >= 2 ? "M19.07 4.93A10 10 0 0 1 19.07 19.07" : ""))
    }

    // Stroked 24x24-viewBox SVG path scaled to `size`, like the workspace icons.
    component SvgIcon: Item {
        id: icon
        property string path
        property color color
        property int size: 14

        implicitWidth: size
        implicitHeight: size

        Shape {
            width: 24
            height: 24
            scale: icon.size / 24
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: icon.color
                strokeWidth: 2
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: icon.path }
            }
        }
    }
}
