// Glow.qml: popup for screen colour temperature (hyprsunset) and backlight brightness.
// State, schedule and IPC live in GlowService; this file is presentation only.
// Open it from a bar button: `Glow { id: glow; anchorItem: button }` + `glow.toggle()`.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland

BarPopup {
    id: popup
    align: "right"

    function toggle() { if (open) close(); else if (!PopupManager.justClosed("glow")) show(); }
    function show() { PopupManager.opened("glow"); visible = true; fadeInDelay.restart(); GlowService.refresh(); }
    function close() { fadeInDelay.stop(); open = false; PopupManager.closed("glow"); hideAfterFade.restart(); }

    // Only one bar popup at a time.
    Connections {
        target: PopupManager
        function onCurrentChanged() { if (popup.visible && PopupManager.current !== "glow") popup.close(); }
    }

    // Poll the backlight only while the popup is open (brightness keys show up live).
    Binding { target: GlowService; property: "watchBacklight"; value: popup.open && Host.glowBrightness }

    cardWidth: 420
    cardHeight: card.implicitHeight
    color: "transparent"
    visible: false

    // Map the window with the card still transparent and start the fade-in a frame
    // later, so the window's very first frame shows nothing (no stale-frame flash).
    Timer { id: fadeInDelay; interval: 16; onTriggered: { popup.open = true; card.forceActiveFocus(); } }

    Timer { id: hideAfterFade; interval: Theme.durationNormal; onTriggered: if (!popup.open) popup.visible = false }

    // Escape + click-outside (without closing instantly, so the fade-out plays).
    readonly property string mode: GlowService.mode
    readonly property color lightColor: GlowService.identity ? "#ffffff" : GlowService.kelvinColor(GlowService.temperature)

    Rectangle {
        id: card

        width: parent.width
        implicitHeight: content.implicitHeight + Theme.popupPadding * 2
        radius: Theme.radiusLarge
        color: Theme.raised
        border.width: Theme.borderWidth
        border.color: Theme.border

        focus: true
        Keys.onEscapePressed: popup.close()

        transformOrigin: Item.TopRight
        opacity: popup.open ? 1 : 0
        scale: popup.open ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }

        Column {
            id: content
            x: Theme.popupPadding
            y: Theme.popupPadding
            width: parent.width - Theme.popupPadding * 2
            spacing: Theme.popupSpacing

            // ---- Header: orb, title, subtitle ----
            Row {
                spacing: 10

                Item {
                    id: orb
                    width: 34
                    height: 34

                    // Soft glow; brighter with higher brightness, faint with original colours.
                    Rectangle {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: width / 2
                        color: popup.lightColor
                        opacity: GlowService.identity ? 0.15
                               : GlowService.brightness < 0 ? 0.45 // backlight not read yet
                               : 0.2 + 0.5 * (GlowService.brightness - GlowService.minBrightness) / (GlowService.maxBrightness - GlowService.minBrightness)
                        layer.enabled: true
                        layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 24 }
                        Behavior on color { ColorAnimation { duration: Theme.durationNormal } }
                    }

                    // Light disc with a ring in the background colour.
                    Rectangle {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        radius: width / 2
                        color: popup.lightColor
                        border.width: 3
                        border.color: Theme.raised
                        Behavior on color { ColorAnimation { duration: Theme.durationNormal } }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: "Glow"
                        color: Theme.textPrimary
                        font.family: Theme.sansFont
                        font.pixelSize: Theme.fontSizeTitle
                    }

                    Text {
                        text: GlowService.subtitle
                        color: Theme.textSecondary
                        font.family: Theme.monoFont
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            // ---- Brightness: the backlight, independent of the colour mode (laptops only) ----
            Column {
                visible: Host.glowBrightness
                width: parent.width
                spacing: 6

                LabelRow {
                    label: "Brightness"
                    value: GlowService.brightness >= 0 ? `${GlowService.brightness}%` : "–"
                }

                GlowSlider {
                    width: parent.width
                    from: GlowService.minBrightness
                    to: GlowService.maxBrightness
                    step: 1
                    value: Math.max(0, GlowService.brightness)
                    leftLabel: "0%"
                    rightLabel: "100%"
                    onMoved: v => GlowService.setBrightness(v)
                }
            }

            Rectangle {
                visible: Host.glowBrightness
                width: parent.width
                height: Theme.borderWidth
                color: Theme.border
            }

            // ---- Colour: mode selector (Schedule / Manual) ----
            Item {
                width: parent.width
                implicitHeight: modeSelector.implicitHeight

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Color"
                    color: Theme.textSecondary
                    font.family: Theme.sansFont
                    font.pixelSize: Theme.fontSize
                }

                ModeSelector {
                    id: modeSelector
                    anchors.right: parent.right
                    width: 220
                    current: popup.mode
                    onSelected: value => GlowService.setMode(value)
                }
            }

            // ---- Schedule: read-only profile list ----
            Column {
                width: parent.width
                spacing: 6
                visible: popup.mode === "schedule"

                Repeater {
                    model: GlowService.schedule

                    delegate: ProfileCard {
                        required property var modelData
                        required property int index
                        width: parent.width
                        profile: modelData
                        active: index === GlowService.activeIndex
                    }
                }

                Text {
                    visible: GlowService.schedule.length === 0
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: (GlowService.configError || "No profiles") + ". Edit " + GlowService.configPath
                    color: Theme.textSecondary
                    font.family: Theme.monoFont
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            // ---- Manual: live sliders ----
            Rectangle {
                width: parent.width
                implicitHeight: manual.implicitHeight + 24
                visible: popup.mode === "manual"
                radius: Theme.radius
                color: Theme.inset
                border.width: Theme.borderWidth
                border.color: Theme.borderSubtle

                Column {
                    id: manual
                    x: 12
                    y: 12
                    width: parent.width - 24
                    spacing: 10

                    // Label + Reset (original colours).
                    Item {
                        width: parent.width
                        implicitHeight: resetButton.height

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "LIVE · OVERRIDES SCHEDULE"
                            color: Theme.textDisabled
                            font.family: Theme.monoFont
                            font.pixelSize: Theme.fontSizeSmall
                            font.letterSpacing: 1
                        }

                        Rectangle {
                            id: resetButton
                            readonly property bool available: !GlowService.manualNeutral
                            anchors.right: parent.right
                            width: resetText.implicitWidth + 16
                            height: resetText.implicitHeight + 8
                            radius: Theme.radiusSmall
                            color: available && resetMouse.containsMouse ? Theme.raisedHigh : Theme.raised

                            Text {
                                id: resetText
                                anchors.centerIn: parent
                                text: "Reset"
                                color: resetButton.available ? Theme.textPrimary : Theme.textDisabled
                                font.family: Theme.sansFont
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            MouseArea {
                                id: resetMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: resetButton.available
                                cursorShape: Qt.PointingHandCursor
                                onClicked: GlowService.resetManual()
                            }
                        }
                    }

                    LabelRow {
                        label: "Temperature"
                        value: `${GlowService.manualNeutral ? GlowService.neutralTemperature : GlowService.manualTemperature} K`
                    }

                    GlowSlider {
                        width: parent.width
                        from: GlowService.minTemperature
                        to: GlowService.maxTemperature
                        step: 100
                        // After Reset the handle rests on the neutral mark.
                        value: GlowService.manualNeutral ? GlowService.neutralTemperature : GlowService.manualTemperature
                        markValue: GlowService.neutralTemperature
                        leftLabel: "1000 K"
                        markLabel: "6500 K neutral"
                        rightLabel: "10000 K"
                        // 1000 → 2700 → 5500 → 6500 → 10000 K across 1000–10000.
                        trackGradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#ff7a28" }
                            GradientStop { position: 0.1889; color: "#ffbe78" }
                            GradientStop { position: 0.5; color: "#fff4e6" }
                            GradientStop { position: 0.6111; color: "#ffffff" }
                            GradientStop { position: 1.0; color: "#bed2ff" }
                        }
                        onMoved: v => GlowService.setManualTemperature(v)
                    }
                }
            }
        }
    }

    // Label on the left, monospace value on the right.
    component LabelRow: Item {
        property string label
        property string value
        width: parent.width
        implicitHeight: labelText.implicitHeight

        Text {
            id: labelText
            text: parent.label
            color: Theme.textSecondary
            font.family: Theme.sansFont
            font.pixelSize: Theme.fontSize
        }

        Text {
            anchors.right: parent.right
            text: parent.value
            color: Theme.textPrimary
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontSize
            font.features: { "tnum": 1 }
        }
    }
}
