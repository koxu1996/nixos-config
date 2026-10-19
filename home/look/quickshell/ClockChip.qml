// ClockChip.qml: bar clock "21:59" (the date is in the popup); click toggles ClockPopup.
// Same hover / open background as the other bar chips.
import QtQuick

Item {
    id: root

    readonly property bool active: popup.open

    implicitWidth: chip.implicitWidth
    implicitHeight: chip.implicitHeight

    Rectangle {
        id: chip

        implicitWidth: row.implicitWidth + Theme.barChipPadding * 2
        implicitHeight: Theme.barChipHeight
        radius: Theme.radiusSmall
        color: root.active || chipMouse.containsMouse ? Theme.chipHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 7

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ClockService.timeText
                color: Theme.accent
                font.family: Theme.monoFont
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                font.features: { "tnum": 1 }
            }
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: popup.toggle()
        }
    }

    ClockPopup {
        id: popup
        anchorItem: chip
    }
}
