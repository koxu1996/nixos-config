// NotificationCentre.qml: popup with Active notifications and Earlier (history),
// a Silence (DND) toggle and Clear all. Opened from NotificationChip.
import QtQuick
import Quickshell
import Quickshell.Hyprland

PopupWindow {
    id: popup

    property Item anchorItem
    property bool open: false

    function toggle() { if (open) close(); else if (!PopupManager.justClosed("notifications")) show(); }
    function show() { PopupManager.opened("notifications"); visible = true; fadeInDelay.restart(); body.contentY = 0; }
    function close() { fadeInDelay.stop(); open = false; PopupManager.closed("notifications"); hideAfterFade.restart(); }

    // Only one bar popup at a time.
    Connections {
        target: PopupManager
        function onCurrentChanged() { if (popup.visible && PopupManager.current !== "notifications") popup.close(); }
    }

    anchor.item: anchorItem
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.margins.bottom: -Theme.popupGap // margins resize the anchor rect; negative = below it

    implicitWidth: 400
    implicitHeight: card.height
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

    readonly property int maxHeight: 640
    readonly property bool empty: NotificationService.count === 0 && NotificationService.history.length === 0

    // History grouped by day: [{ label, entries }] (history is newest first).
    readonly property var groups: {
        const out = [];
        for (const entry of NotificationService.history) {
            const label = NotificationService.dayLabel(entry.time);
            if (out.length === 0 || out[out.length - 1].label !== label) out.push({ label: label, entries: [] });
            out[out.length - 1].entries.push(entry);
        }
        return out;
    }

    Rectangle {
        id: card

        width: parent.width
        height: Math.min(popup.maxHeight, content.implicitHeight + Theme.popupPadding * 2)
        radius: Theme.radiusLarge
        color: Theme.raised
        border.width: Theme.borderWidth
        border.color: Theme.border
        clip: true

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

            // ---- Header ----
            Item {
                width: parent.width
                implicitHeight: 26

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Notifications"
                        color: Theme.textPrimary
                        font.family: Theme.sansFont
                        font.pixelSize: Theme.fontSizeLarge
                    }

                    Rectangle {
                        visible: NotificationService.count > 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: countText.implicitWidth + 12
                        height: countText.implicitHeight + 4
                        radius: Theme.radiusSmall
                        color: Theme.raisedHigh

                        Text {
                            id: countText
                            anchors.centerIn: parent
                            text: NotificationService.count
                            color: Theme.textSecondary
                            font.family: Theme.monoFont
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // Silence (DND) toggle.
                    Rectangle {
                        readonly property bool silenced: NotificationService.dnd
                        width: silenceRow.implicitWidth + 16
                        height: 26
                        radius: Theme.radiusSmall
                        color: silenced ? Theme.accentBg : silenceMouse.containsMouse ? Theme.hover : "transparent"

                        Row {
                            id: silenceRow
                            anchors.centerIn: parent
                            spacing: 6

                            AppGlyph {
                                anchors.verticalCenter: parent.verticalCenter
                                kind: parent.parent.silenced ? "bellOff" : "bell"
                                size: 12
                                color: parent.parent.silenced ? Theme.accent : Theme.textSecondary
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.parent.silenced ? "Silenced" : "Silence"
                                color: parent.parent.silenced ? Theme.accent : Theme.textSecondary
                                font.family: Theme.sansFont
                                font.pixelSize: Theme.fontSize
                            }
                        }

                        MouseArea {
                            id: silenceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotificationService.setDnd(!NotificationService.dnd)
                        }
                    }

                    // Clear all (both lists).
                    Rectangle {
                        readonly property bool canClear: !popup.empty
                        width: clearText.implicitWidth + 16
                        height: 26
                        radius: Theme.radiusSmall
                        color: canClear && clearMouse.containsMouse ? Theme.hover : "transparent"

                        Text {
                            id: clearText
                            anchors.centerIn: parent
                            text: "Clear all"
                            color: parent.canClear ? Theme.textSecondary : Theme.textFaint
                            font.family: Theme.sansFont
                            font.pixelSize: Theme.fontSize
                        }

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: parent.canClear
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotificationService.clearAll()
                        }
                    }
                }
            }

            // ---- DND banner ----
            Rectangle {
                visible: NotificationService.dnd
                width: parent.width
                implicitHeight: bannerRow.implicitHeight + 20
                radius: Theme.radius
                color: Theme.accentBg

                Row {
                    id: bannerRow
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 24
                    spacing: 8

                    AppGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "bellOff"
                        size: Theme.iconSize
                        color: Theme.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.iconSize - parent.spacing
                        wrapMode: Text.Wrap
                        text: "Toasts are hidden. Critical notifications still show."
                        color: Theme.accent
                        font.family: Theme.sansFont
                        font.pixelSize: Theme.fontSize
                    }
                }
            }

            // ---- Empty state ----
            Column {
                visible: popup.empty
                width: parent.width
                topPadding: 18
                bottomPadding: 18
                spacing: 6

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 44
                    height: 44
                    radius: Theme.radius
                    color: Theme.inset

                    AppGlyph {
                        anchors.centerIn: parent
                        kind: "bell"
                        size: 18
                        color: Theme.textDisabled
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 4
                    text: "All caught up"
                    color: Theme.textPrimary
                    font.family: Theme.sansFont
                    font.pixelSize: Theme.fontSizeTitle
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "no notifications"
                    color: Theme.textDisabled
                    font.family: Theme.monoFont
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            // ---- Scrolling body: Active + Earlier ----
            Item {
                visible: !popup.empty
                width: parent.width
                // Fill what is left of the max height; shrink to content otherwise.
                readonly property real available: popup.maxHeight - Theme.popupPadding * 2
                    - 26 - Theme.popupSpacing
                    - (NotificationService.dnd ? 56 + Theme.popupSpacing : 0)
                implicitHeight: Math.min(available, bodyColumn.implicitHeight)

                Flickable {
                    id: body
                    anchors.fill: parent
                    contentHeight: bodyColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: bodyColumn
                        width: body.width - (scrollbar.visible ? 8 : 0)
                        spacing: 10

                        // Active
                        SectionLabel {
                            visible: NotificationService.count > 0
                            text: `ACTIVE · ${NotificationService.count}`
                        }

                        Repeater {
                            model: NotificationService.activeNewestFirst
                            delegate: NotificationCard {
                                required property var modelData
                                width: bodyColumn.width
                                notification: modelData
                            }
                        }

                        // Earlier, grouped by day.
                        Repeater {
                            model: popup.groups

                            delegate: Column {
                                id: group
                                required property var modelData
                                required property int index
                                width: bodyColumn.width
                                spacing: 2

                                SectionLabel {
                                    topPadding: group.index === 0 && NotificationService.count === 0 ? 0 : 10
                                    bottomPadding: 6
                                    text: group.modelData.label
                                }

                                Repeater {
                                    model: group.modelData.entries
                                    delegate: HistoryRow {
                                        required property var modelData
                                        width: group.width
                                        entry: modelData
                                        onOpened: popup.close()
                                    }
                                }
                            }
                        }
                    }
                }

                // Thin scrollbar.
                Rectangle {
                    id: scrollbar
                    visible: body.contentHeight > body.height + 1
                    anchors.right: parent.right
                    y: body.visibleArea.yPosition * body.height
                    width: 3
                    height: body.visibleArea.heightRatio * body.height
                    radius: 1.5
                    color: Theme.border
                }
            }
        }
    }

    component SectionLabel: Text {
        color: Theme.textSecondary
        font.family: Theme.monoFont
        font.pixelSize: Theme.fontSizeSmall
        font.capitalization: Font.AllUppercase
    }
}
