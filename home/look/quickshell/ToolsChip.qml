// ToolsChip.qml: wrench chip; click (or `tools toggle` over IPC) toggles ToolsMenu.
import QtQuick

Item {
    id: root

    implicitWidth: chip.implicitWidth
    implicitHeight: chip.implicitHeight

    Rectangle {
        id: chip

        implicitWidth: Theme.barIconSize + Theme.barChipPadding * 2
        implicitHeight: Theme.barChipHeight
        radius: Theme.radiusSmall
        color: (chipMouse.containsMouse || PopupManager.hovers(chipMouse)) || menu.open ? Theme.chipHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        AppGlyph {
            anchors.centerIn: parent
            kind: "wrench"
            size: Theme.barIconSize
            color: Theme.accent
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: menu.toggle()
        }
    }

    Connections {
        target: ToolsService
        function onToggleRequested() { menu.toggle(); }
    }

    ToolsMenu {
        id: menu
        anchorItem: chip
    }
}
