// ClockPopup.qml: big time, full date, ISO week line, month calendar and time zones.
// Opened from ClockChip; seconds precision only while open.
import QtQuick
import Quickshell
import Quickshell.Hyprland

PopupWindow {
    id: popup

    property Item anchorItem
    property bool open: false

    function toggle() { if (open) close(); else if (!PopupManager.justClosed("clock")) show(); }
    function show() { PopupManager.opened("clock"); calendar.goToday(); visible = true; fadeInDelay.restart(); ClockService.readZones(); }
    function close() { fadeInDelay.stop(); open = false; PopupManager.closed("clock"); hideAfterFade.restart(); }

    // Only one bar popup at a time.
    Connections {
        target: PopupManager
        function onCurrentChanged() { if (popup.visible && PopupManager.current !== "clock") popup.close(); }
    }

    // Seconds only while open.
    Binding { target: ClockService; property: "precise"; value: popup.open }

    anchor.item: anchorItem
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.margins.bottom: -Theme.popupGap // margins resize the anchor rect; negative = below it

    implicitWidth: 420
    implicitHeight: card.implicitHeight
    color: "transparent"
    visible: false

    // Map the window with the card still transparent and start the fade-in a frame
    // later, so the window's very first frame shows nothing (no stale-frame flash).
    Timer { id: fadeInDelay; interval: 16; onTriggered: { popup.open = true; card.forceActiveFocus(); } }

    Timer { id: hideAfterFade; interval: Theme.durationNormal; onTriggered: if (!popup.open) popup.visible = false }

    HyprlandFocusGrab {
        windows: [popup]
        active: popup.visible
        onCleared: popup.close()
    }

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

            // ---- Time block ----
            Column {
                x: 4
                width: parent.width - 8
                spacing: 4

                Row {
                    spacing: 2

                    Text {
                        id: bigTime
                        text: ClockService.timeText
                        color: Theme.textPrimary
                        font.family: Theme.monoFont
                        font.pixelSize: Theme.fontSizeDisplay
                        font.weight: Font.Medium
                        font.letterSpacing: -2
                        font.features: { "tnum": 1 }
                    }

                    Text {
                        anchors.baseline: bigTime.baseline
                        text: ClockService.secondsText
                        color: Theme.textDisabled
                        font.family: Theme.monoFont
                        font.pixelSize: 20
                        font.features: { "tnum": 1 }
                    }
                }

                Text {
                    text: ClockService.longDate
                    color: Theme.textPrimary
                    font.family: Theme.sansFont
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                }

                Text {
                    text: ClockService.weekLine
                    color: Theme.textSecondary
                    font.family: Theme.monoFont
                    font.pixelSize: Theme.fontSize
                }
            }

            MonthCalendar {
                id: calendar
                width: parent.width
            }

            ZoneList {
                width: parent.width
            }
        }
    }
}
