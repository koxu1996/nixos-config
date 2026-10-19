// HistoryRow.qml: one past notification (history snapshot). No actions; clicking opens
// or focuses the app (desktop entry) and asks the popup to close.
import QtQuick

Rectangle {
    id: row

    property var entry
    signal opened()

    implicitHeight: textColumn.implicitHeight + 16
    radius: Theme.radius
    color: mouse.containsMouse ? Theme.hover : "transparent"

    Rectangle {
        id: tile
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        height: 22
        radius: Theme.radiusSmall
        color: Theme.raisedHigh

        AppGlyph {
            anchors.centerIn: parent
            kind: "bell"
            size: 12
            color: row.entry?.critical ? Theme.error : Theme.textSecondary
        }
    }

    Column {
        id: textColumn
        x: tile.x + tile.width + 10
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - time.width - 20
        spacing: 1

        Text {
            width: parent.width
            elide: Text.ElideRight
            maximumLineCount: 1
            text: row.entry?.summary || row.entry?.appName || ""
            color: Theme.textPrimary
            font.family: Theme.sansFont
            font.pixelSize: Theme.fontSize
            font.weight: Font.Medium
        }

        Text {
            visible: text !== ""
            width: parent.width
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.StyledText
            text: (row.entry?.body ?? "").replace(/\n/g, " ")
            color: Theme.textSecondary
            font.family: Theme.sansFont
            font.pixelSize: Theme.fontSize
        }
    }

    Text {
        id: time
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: NotificationService.clockTime(row.entry?.time ?? 0)
        color: Theme.textDisabled
        font.family: Theme.monoFont
        font.pixelSize: Theme.fontSizeSmall
        font.features: { "tnum": 1 }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            NotificationService.openApp(row.entry);
            row.opened();
        }
    }
}
