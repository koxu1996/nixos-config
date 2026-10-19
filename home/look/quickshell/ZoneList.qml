// ZoneList.qml: extra time zones (from ClockService.zoneTimes) with offsets from local time.
import QtQuick

Rectangle {
    id: list

    visible: ClockService.zoneTimes.length > 0
    implicitHeight: rows.implicitHeight + 2
    radius: Theme.radius
    color: Theme.inset
    border.width: Theme.borderWidth
    border.color: Theme.borderSubtle
    clip: true

    Column {
        id: rows
        x: 1
        y: 1
        width: parent.width - 2

        Repeater {
            model: ClockService.zoneTimes

            delegate: Column {
                id: zone
                required property var modelData
                required property int index
                width: rows.width

                // Hairline divider between rows.
                Rectangle {
                    visible: zone.index > 0
                    width: parent.width
                    height: 1
                    color: Theme.borderSubtle
                }

                Item {
                    width: parent.width
                    implicitHeight: name.implicitHeight + 20

                    Text {
                        id: name
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 24 - offset.width - time.width - 24
                        elide: Text.ElideRight
                        text: zone.modelData.name
                        color: Theme.textPrimary
                        font.family: Theme.sansFont
                        font.pixelSize: Theme.fontSize
                        font.weight: Font.Medium
                    }

                    Text {
                        id: offset
                        anchors.right: time.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: zone.modelData.offset
                        color: Theme.textSecondary
                        font.family: Theme.monoFont
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Text {
                        id: time
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(44, implicitWidth)
                        horizontalAlignment: Text.AlignRight
                        text: zone.modelData.time
                        color: Theme.textPrimary
                        font.family: Theme.monoFont
                        font.pixelSize: Theme.fontSizeTitle
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }
    }
}
