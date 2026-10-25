// NotificationChip.qml: bell + active count; red dot while a Critical is tracked;
// bellOff when Do Not Disturb is on; click toggles the NotificationCentre popup.
import QtQuick

Item {
    id: root

    readonly property bool active: centre.open
    readonly property int count: NotificationService.count
    readonly property bool dnd: NotificationService.dnd
    readonly property color fg: active ? Theme.accent
                              : dnd ? Theme.textDisabled
                              : Theme.accent

    implicitWidth: chip.implicitWidth
    implicitHeight: chip.implicitHeight

    Accessible.role: Accessible.Button
    Accessible.name: `${count} notifications${dnd ? ", do not disturb on" : ""}`

    Rectangle {
        id: chip

        implicitWidth: row.implicitWidth + Theme.barChipPadding * 2
        implicitHeight: Theme.barChipHeight
        radius: Theme.radiusSmall
        color: root.active || (chipMouse.containsMouse || PopupManager.hovers(chipMouse)) ? Theme.chipHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.barIconSize
                height: Theme.barIconSize

                AppGlyph {
                    kind: root.dnd ? "bellOff" : "bell"
                    size: Theme.barIconSize
                    color: root.fg
                }

                // Critical dot (6 px + 2 px ring in the bar colour).
                Rectangle {
                    visible: NotificationService.hasCritical
                    x: parent.width - 6
                    y: -3
                    width: 10
                    height: 10
                    radius: 5
                    color: Theme.error
                    border.width: 2
                    border.color: Theme.base
                }
            }

            Text {
                visible: root.count > 0
                anchors.verticalCenter: parent.verticalCenter
                text: root.count > 9 ? "9+" : root.count
                color: root.fg
                font.family: Theme.monoFont
                font.pixelSize: Theme.fontSize
                font.features: { "tnum": 1 }
            }
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: centre.toggle()
        }
    }

    NotificationCentre {
        id: centre
        anchorItem: chip
    }
}
