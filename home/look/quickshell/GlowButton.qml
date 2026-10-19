// GlowButton.qml: bar chip for Glow: a sun icon (dimmed for original colours);
// left click opens the Glow popup.
import QtQuick

Item {
    id: root

    readonly property bool disabled: GlowService.identity // original colours

    implicitWidth: chip.implicitWidth
    implicitHeight: chip.implicitHeight

    Rectangle {
        id: chip

        implicitWidth: icon.implicitWidth + Theme.barChipPadding * 2
        implicitHeight: Theme.barChipHeight
        radius: Theme.radiusSmall
        color: chipMouse.containsMouse || glow.open ? Theme.chipHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        // Sun icon: lime while a colour temperature is applied, dimmed for original colours.
        AppGlyph {
            id: icon
            anchors.centerIn: parent
            kind: "sun"
            size: Theme.barIconSize
            color: root.disabled ? Theme.textDisabled : Theme.accent
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: glow.toggle()
        }
    }

    Glow {
        id: glow
        anchorItem: chip
    }
}
