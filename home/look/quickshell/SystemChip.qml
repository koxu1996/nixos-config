// SystemChip.qml: snowflake chip at the far left of the bar; click toggles SystemMenu.
// Icon: the theme's `nix-snowflake` if it has one, otherwise the `snowflake` glyph in lime.
import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    readonly property string themeIcon: Quickshell.iconPath("nix-snowflake", true)

    implicitWidth: chip.implicitWidth
    implicitHeight: chip.implicitHeight

    Rectangle {
        id: chip

        implicitWidth: 18 + Theme.barChipPadding * 2
        implicitHeight: Theme.barChipHeight
        radius: Theme.radiusSmall
        color: menu.open || (chipMouse.containsMouse || PopupManager.hovers(chipMouse)) ? Theme.chipHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        Item {
            id: icon
            anchors.centerIn: parent
            width: 18
            height: 18
            rotation: (chipMouse.containsMouse || PopupManager.hovers(chipMouse)) ? 30 : 0
            Behavior on rotation { NumberAnimation { duration: Theme.durationSlow; easing.type: Easing.OutCubic } }

            IconImage {
                anchors.fill: parent
                visible: root.themeIcon !== ""
                source: root.themeIcon
                implicitSize: 18
            }

            AppGlyph {
                anchors.fill: parent
                visible: root.themeIcon === ""
                kind: "snowflake"
                size: 18
                color: Theme.accent
            }
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: menu.toggle()
        }
    }

    SystemMenu {
        id: menu
        anchorItem: chip
    }
}
