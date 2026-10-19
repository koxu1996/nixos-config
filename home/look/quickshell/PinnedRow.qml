// PinnedRow.qml: one pinned app in the launcher: icon tile, display name (matched
// characters in lime), command name and a ↵ when selected.
import QtQuick
import Quickshell.Widgets

Rectangle {
    id: row

    // { app: { id, name, icon, entry }, indices, onCommand }
    property var item
    property bool selected: false

    signal activated()

    implicitHeight: 44
    radius: Theme.radius
    color: selected ? Theme.accentBg : Theme.inset
    border.width: Theme.borderWidth
    border.color: selected ? Theme.alpha(Theme.accent, 0.55) : Theme.borderSubtle

    Rectangle {
        id: tile
        x: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: 32
        radius: Theme.radiusSmall
        color: Theme.raisedHigh
        border.width: Theme.borderWidth
        border.color: Theme.border

        IconImage {
            anchors.centerIn: parent
            visible: row.item.app.entry !== null
            implicitSize: 20
            source: row.item.app.icon
            asynchronous: true
        }

        AppGlyph {
            anchors.centerIn: parent
            visible: row.item.app.entry === null
            kind: "terminal"
            size: 16
            color: Theme.textSecondary
        }
    }

    Text {
        anchors.left: tile.right
        anchors.leftMargin: 12
        anchors.right: command.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        textFormat: Text.StyledText
        text: LauncherService.highlight(row.item.app.name, row.item.onCommand ? [] : row.item.indices)
        color: row.selected ? Theme.accent : Theme.textPrimary
        font.family: Theme.sansFont
        font.pixelSize: 14
        font.weight: Font.Medium
    }

    Text {
        id: command
        anchors.right: enter.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.StyledText
        text: LauncherService.highlight(row.item.app.id, row.item.onCommand ? row.item.indices : [])
        color: Theme.textDisabled
        font.family: Theme.monoFont
        font.pixelSize: 11
    }

    // 10px slot for the ↵ on the selected row.
    Text {
        id: enter
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 10
        horizontalAlignment: Text.AlignHCenter
        text: "↵"
        visible: row.selected
        color: Theme.accent
        font.family: Theme.monoFont
        font.pixelSize: Theme.fontSize
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.activated()
    }
}
