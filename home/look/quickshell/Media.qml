// Media.qml: now-playing chip and panel for MPRIS players (state in MediaService.qml).
// Chip: cover, equaliser and "Title · Artist" (hidden when `compact`).
// Left click: panel. Middle click: play/pause. Scroll: next/previous.
// Lime accent like the other widgets: equaliser, progress and slider fills.
// Checked against Quickshell 0.3.0. Use it as `Media {}` in the bar's right-end Row.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Widgets

Item {
    id: root

    // Cover + equaliser only, when the bar has no room for the title.
    property bool compact: false

    readonly property MprisPlayer player: MediaService.active
    readonly property bool playing: player?.isPlaying ?? false
    readonly property real progress: player && player.length > 0
        ? Math.max(0, Math.min(1, player.position / player.length)) : 0

    function escapeHtml(s) {
        return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    // Only for an actual track: browsers keep a "Stopped" player with no title (and their own
    // icon as art) around when nothing plays. Paused tracks stay, so they can be resumed.
    visible: player !== null && player.playbackState !== MprisPlaybackState.Stopped && player.trackTitle !== ""
    implicitWidth: chip.width
    implicitHeight: chip.height

    // ---- Chip --------------------------------------------------------------
    Rectangle {
        id: chip

        readonly property real fixedWidth: Theme.barChipPadding + chipCover.width + 7 + chipEq.width + Theme.barChipPadding

        width: root.compact ? fixedWidth : Math.min(180, fixedWidth + 1 + chipLabel.implicitWidth + 8)
        height: Theme.barChipHeight
        radius: Theme.radiusSmall
        color: chipMouse.containsMouse || panel.open ? Theme.chipHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        Cover {
            id: chipCover
            x: Theme.barChipPadding
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -1
            width: 20
            height: 20
            radius: 4
            url: root.player?.trackArtUrl ?? ""
        }

        Equaliser {
            id: chipEq
            anchors.left: chipCover.right
            anchors.leftMargin: 7
            anchors.verticalCenter: chipCover.verticalCenter
            playing: root.playing
        }

        Text {
            id: chipLabel
            visible: !root.compact
            anchors.left: chipEq.right
            anchors.leftMargin: 8
            anchors.verticalCenter: chipCover.verticalCenter
            width: chip.width - x - 8
            elide: Text.ElideRight
            textFormat: Text.StyledText
            text: {
                const artist = MediaService.artist(root.player);
                return root.escapeHtml(MediaService.title(root.player))
                    + (artist ? `<font color="${Theme.textSecondary}"> · ${root.escapeHtml(artist)}</font>` : "");
            }
            color: Theme.textPrimary
            opacity: root.playing ? 1 : 0.6
            font.family: Theme.sansFont
            font.pixelSize: Theme.fontSize
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton

            property real wheelAccum: 0
            property real wheelLockedUntil: 0

            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton) MediaService.togglePlaying(root.player);
                else panel.toggle();
            }

            // One track per gesture: a full notch, then 400 ms of ignored scrolling.
            onWheel: wheel => {
                if (Date.now() < wheelLockedUntil) { wheelAccum = 0; return; }
                wheelAccum += wheel.angleDelta.y || wheel.angleDelta.x;
                if (Math.abs(wheelAccum) < 120) return;
                if (wheelAccum < 0) MediaService.next(root.player);
                else MediaService.previous(root.player);
                wheelAccum = 0;
                wheelLockedUntil = Date.now() + 400;
            }
        }
    }

    // ---- Panel -------------------------------------------------------------
    BarPopup {
        id: panel
        anchorItem: chip
        align: "right"

        function toggle() { if (open) close(); else if (!PopupManager.justClosed("media")) show(); }
        // Map the window with the card still transparent, and start the fade-in a frame
        // later, so the window's very first frame shows nothing.
        function show() { PopupManager.opened("media"); visible = true; fadeInDelay.restart(); }

        Timer { id: fadeInDelay; interval: 16; onTriggered: { panel.open = true; card.forceActiveFocus(); } }
        function close() { fadeInDelay.stop(); open = false; PopupManager.closed("media"); hideAfterFade.restart(); }

        // Only one bar popup at a time (PopupManager).
        Connections {
            target: PopupManager
            function onCurrentChanged() { if (panel.visible && PopupManager.current !== "media") panel.close(); }
        }

        // The last player went away while open.
        Connections {
            target: root
            function onPlayerChanged() { if (!root.player && panel.open) panel.close(); }
        }

        cardWidth: 340
        cardHeight: card.implicitHeight
        color: "transparent"
        visible: false

        Timer { id: hideAfterFade; interval: Theme.durationNormal; onTriggered: if (!panel.open) panel.visible = false }

        Rectangle {
            id: card

            width: parent.width
            implicitHeight: content.implicitHeight + Theme.popupPadding * 2
            radius: Theme.radiusLarge
            color: Theme.raised
            border.width: Theme.borderWidth
            border.color: Theme.border

            focus: true
            Keys.onEscapePressed: panel.close()

            transformOrigin: Item.TopRight
            opacity: panel.open ? 1 : 0
            scale: panel.open ? 1 : 0.94
            Behavior on opacity { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }

            // Soft accent glow behind the top of the card.
            ClippingRectangle {
                anchors.fill: parent
                anchors.margins: Theme.borderWidth
                radius: card.radius - Theme.borderWidth
                color: "transparent"

                Shape {
                    width: parent.width
                    height: 200
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeWidth: -1
                        fillGradient: RadialGradient {
                            centerX: card.width / 2
                            centerY: 0
                            centerRadius: card.width * 0.6
                            focalX: centerX
                            focalY: centerY
                            GradientStop { position: 0; color: Theme.alpha(Theme.accent, 0.08) }
                            GradientStop { position: 1; color: Theme.alpha(Theme.accent, 0) }
                        }
                        PathRectangle { width: card.width; height: 200 }
                    }
                }
            }

            Column {
                id: content
                x: Theme.popupPadding
                y: Theme.popupPadding
                width: parent.width - Theme.popupPadding * 2
                spacing: Theme.popupSpacing

                // 1. Player tabs.
                Flow {
                    width: parent.width
                    spacing: 6
                    visible: MediaService.players.length >= 2

                    Repeater {
                        model: MediaService.players

                        delegate: Rectangle {
                            id: tab
                            required property MprisPlayer modelData
                            readonly property bool current: modelData === root.player

                            width: tabRow.implicitWidth + 20
                            height: 24
                            radius: Theme.radiusSmall
                            color: current ? Theme.accentBg : tabMouse.containsMouse ? Theme.track : Theme.inset

                            Row {
                                id: tabRow
                                anchors.centerIn: parent
                                spacing: 6

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: tab.modelData.isPlaying ? Theme.accent : Theme.textFaint
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: MediaService.appName(tab.modelData)
                                    color: tab.current ? Theme.accent : Theme.textSecondary
                                    font.family: Theme.sansFont
                                    font.pixelSize: Theme.fontSize
                                }
                            }

                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: MediaService.select(tab.modelData)
                            }
                        }
                    }
                }

                // 2. Track.
                Row {
                    width: parent.width
                    spacing: 14

                    Cover {
                        id: bigCover
                        width: 96
                        height: 96
                        radius: Theme.radius
                        url: root.player?.trackArtUrl ?? ""
                        iconSize: 32

                        scale: root.playing ? 1 : 0.94
                        Behavior on scale { NumberAnimation { duration: Theme.durationSlow; easing.type: Easing.OutCubic } }

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Theme.shadow
                            shadowVerticalOffset: 10
                            shadowBlur: 1.0
                            blurMax: 30
                            shadowScale: 0.92
                        }
                    }

                    Column {
                        width: parent.width - bigCover.width - parent.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            width: parent.width
                            text: MediaService.title(root.player)
                            color: Theme.textPrimary
                            font.family: Theme.sansFont
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: MediaService.artist(root.player)
                            color: Theme.textSecondary
                            font.family: Theme.sansFont
                            font.pixelSize: Theme.fontSizeTitle
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: root.player?.trackAlbum ?? ""
                            color: Theme.textDisabled
                            font.family: Theme.monoFont
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            topPadding: 4
                            text: MediaService.sourceLabel(root.player).toUpperCase()
                            color: Theme.textDisabled
                            font.family: Theme.sansFont
                            font.pixelSize: Theme.fontSizeSmall
                            font.letterSpacing: 0.8
                            elide: Text.ElideRight
                        }
                    }
                }

                // 3. Seek.
                Column {
                    width: parent.width
                    spacing: 4

                    Slider {
                        id: seek
                        width: parent.width
                        enabled: root.player?.canSeek ?? false
                        value: root.progress
                        onReleased: v => MediaService.seek(root.player, v * root.player.length)
                    }

                    Item {
                        width: parent.width
                        height: elapsed.implicitHeight

                        readonly property real shownPosition: seek.dragging
                            ? seek.dragValue * (root.player?.length ?? 0) : (root.player?.position ?? 0)

                        Text {
                            id: elapsed
                            text: MediaService.formatTime(parent.shownPosition)
                            color: Theme.textDisabled
                            font.family: Theme.monoFont
                            font.pixelSize: Theme.fontSizeSmall
                            font.features: { "tnum": 1 }
                        }

                        Text {
                            anchors.right: parent.right
                            text: "-" + MediaService.formatTime((root.player?.length ?? 0) - parent.shownPosition)
                            color: Theme.textDisabled
                            font.family: Theme.monoFont
                            font.pixelSize: Theme.fontSizeSmall
                            font.features: { "tnum": 1 }
                        }
                    }
                }

                // 4. Controls.
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 18

                    ControlButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "previous"
                        enabled: (root.player?.canGoPrevious ?? false) || (root.player?.canSeek ?? false)
                        onClicked: MediaService.previous(root.player)
                    }

                    Rectangle {
                        id: playButton
                        anchors.verticalCenter: parent.verticalCenter
                        width: 48
                        height: 48
                        radius: 24
                        color: Theme.textPrimary
                        scale: playMouse.pressed ? 0.94 : playMouse.containsMouse ? 1.04 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic } }

                        MediaIcon {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: root.playing ? 0 : 1
                            size: 20
                            kind: root.playing ? "pause" : "play"
                            color: Theme.base
                        }

                        MouseArea {
                            id: playMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MediaService.togglePlaying(root.player)
                        }
                    }

                    ControlButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "next"
                        enabled: root.player?.canGoNext ?? false
                        onClicked: MediaService.next(root.player)
                    }
                }

                // 5. App volume.
                Row {
                    width: parent.width
                    spacing: 10
                    visible: MediaService.streamAvailable

                    MediaIcon {
                        id: speaker
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "speaker"
                        color: Theme.accent
                    }

                    Text {
                        id: streamLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: MediaService.appName(root.player) + " audio"
                        color: Theme.textSecondary
                        font.family: Theme.sansFont
                        font.pixelSize: Theme.fontSize
                    }

                    Slider {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - speaker.width - streamLabel.width - streamValue.width - parent.spacing * 3
                        value: MediaService.streamVolume
                        live: true
                        onMoved: v => MediaService.setStreamVolume(v)
                        onStepped: d => MediaService.setStreamVolume(Math.round((MediaService.streamVolume + d) * 20) / 20)
                    }

                    Text {
                        id: streamValue
                        anchors.verticalCenter: parent.verticalCenter
                        width: percentMetrics.width
                        horizontalAlignment: Text.AlignRight
                        text: Math.round(MediaService.streamVolume * 100) + "%"
                        color: Theme.textPrimary
                        font.family: Theme.monoFont
                        font.pixelSize: Theme.fontSize
                        font.features: { "tnum": 1 }
                    }

                    TextMetrics {
                        id: percentMetrics
                        font.family: Theme.monoFont
                        font.pixelSize: Theme.fontSize
                        text: "100%"
                    }
                }
            }
        }
    }

    // ---- Pieces ------------------------------------------------------------
    // Rounded cover art, or a music note when there is none.
    component Cover: ClippingRectangle {
        id: cover
        property string url
        property int iconSize: 11

        color: Theme.inset

        AppGlyph {
            anchors.centerIn: parent
            visible: art.status !== Image.Ready
            kind: "music"
            size: cover.iconSize
            color: Theme.textDisabled
        }

        Image {
            id: art
            anchors.fill: parent
            source: cover.url
            sourceSize.width: cover.width * 2
            sourceSize.height: cover.height * 2
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false // browsers reuse temp files for new art
            visible: status === Image.Ready
        }
    }

    // Three bars bouncing at different rates while playing; flat when paused.
    component Equaliser: Row {
        id: eq
        property bool playing: false

        spacing: 2
        height: 10

        Repeater {
            model: [900, 700, 1100]

            delegate: Rectangle {
                required property int modelData
                property real phase: 0

                anchors.bottom: parent.bottom
                width: 2
                radius: 1
                height: eq.playing ? 3 + 7 * (0.5 - 0.5 * Math.cos(phase * 2 * Math.PI)) : 3
                color: eq.playing ? Theme.accent : Theme.textDisabled

                NumberAnimation on phase {
                    from: 0
                    to: 1
                    duration: modelData
                    loops: Animation.Infinite
                    running: eq.playing
                }
            }
        }
    }

    // Track with an accent fill and a white handle. Reports `released(value)` after a
    // drag (seeking on every move would flood the player), or `moved` when `live`.
    component Slider: Item {
        id: slider

        property real value: 0
        property bool live: false
        property bool dragging: false
        property real dragValue: 0
        readonly property real shown: dragging ? dragValue : Math.max(0, Math.min(1, value))
        readonly property real handleSize: 14
        readonly property real usable: width - handleSize

        signal moved(real value)
        signal released(real value)
        signal stepped(real delta)

        height: 18
        opacity: enabled ? 1 : 0.4

        Rectangle {
            id: sliderTrack
            x: slider.handleSize / 2
            width: slider.usable
            height: 6
            radius: 3
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.track

            Rectangle {
                width: Math.max(height, sliderTrack.width * slider.shown)
                height: parent.height
                radius: 3
                visible: slider.shown > 0
                gradient: AccentGradient {}
            }
        }

        Rectangle {
            visible: slider.enabled
            width: slider.handleSize
            height: slider.handleSize
            radius: width / 2
            x: slider.usable * slider.shown
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.textPrimary
        }

        MouseArea {
            anchors.fill: parent
            enabled: slider.enabled
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            function at(mx) { return Math.max(0, Math.min(1, (mx - slider.handleSize / 2) / slider.usable)); }

            onPressed: mouse => {
                slider.dragValue = at(mouse.x);
                slider.dragging = true;
                if (slider.live) slider.moved(slider.dragValue);
            }
            onPositionChanged: mouse => {
                if (!pressed) return;
                slider.dragValue = at(mouse.x);
                if (slider.live) slider.moved(slider.dragValue);
            }
            onReleased: {
                slider.dragging = false;
                slider.released(slider.dragValue);
            }
            onCanceled: slider.dragging = false
            onWheel: wheel => slider.stepped(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
        }
    }

    // Previous / next.
    component ControlButton: Rectangle {
        id: button
        property string icon
        signal clicked()

        width: 36
        height: 36
        radius: 18
        color: buttonMouse.containsMouse && enabled ? Theme.track : "transparent"
        opacity: enabled ? 1 : 0.35

        MediaIcon {
            anchors.centerIn: parent
            size: 16
            kind: button.icon
            color: Theme.textPrimary
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            enabled: button.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    // Filled transport icons and a stroked speaker, in a 24x24 viewBox.
    component MediaIcon: Item {
        id: mediaIcon
        property string kind
        property color color
        property int size: Theme.iconSize

        readonly property var paths: ({
            play: "M7 4.5L19.5 12L7 19.5Z",
            pause: "M6.5 4.5H9.5V19.5H6.5Z M14.5 4.5H17.5V19.5H14.5Z",
            previous: "M18.5 5L8.5 12L18.5 19Z M5.5 5V19",
            next: "M5.5 5L15.5 12L5.5 19Z M18.5 5V19",
            speaker: "M11 5L6 9H2V15H6L11 19Z M15.54 8.46A5 5 0 0 1 15.54 15.54"
        })

        implicitWidth: size
        implicitHeight: size

        Shape {
            width: 24
            height: 24
            scale: mediaIcon.size / 24
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: mediaIcon.kind === "speaker" ? "transparent" : mediaIcon.color
                strokeColor: mediaIcon.color
                strokeWidth: 2
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: mediaIcon.paths[mediaIcon.kind] ?? "" }
            }
        }
    }
}
