// CommandRow.qml: one command in the launcher list: dot, name in mono (matched characters
// in lime) and a ↵ when selected.
import QtQuick

Rectangle {
    id: row

    property string name
    property var indices: []
    property bool selected: false

    signal activated()

    implicitHeight: 30
    radius: Theme.radiusSmall
    color: selected ? Theme.raisedHigh : mouse.containsMouse ? Theme.hover : "transparent"

    Rectangle {
        id: dot
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 6
        height: 6
        radius: 3
        color: row.selected ? Theme.accent : Theme.border
    }

    Text {
        anchors.left: dot.right
        anchors.leftMargin: 10
        anchors.right: enter.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        textFormat: Text.StyledText
        text: LauncherService.highlight(row.name, row.indices)
        color: row.selected ? Theme.textPrimary : Theme.textSecondary
        font.family: Theme.monoFont
        font.pixelSize: Theme.fontSize
    }

    Text {
        id: enter
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: "↵"
        visible: row.selected
        color: Theme.accent
        font.family: Theme.monoFont
        font.pixelSize: Theme.fontSize
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.activated()
    }
}
