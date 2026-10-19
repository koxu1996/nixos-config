// ModeSelector.qml: segmented control for Glow (Schedule · Manual).
import QtQuick

Rectangle {
    id: selector

    property var options: [
        { value: "schedule", label: "Schedule" },
        { value: "manual", label: "Manual" },
    ]
    property string current: ""
    signal selected(string value)

    implicitHeight: Theme.barItemHeight + 8
    radius: Theme.radius
    color: Theme.inset
    border.width: Theme.borderWidth
    border.color: Theme.border

    Row {
        id: pills
        anchors.fill: parent
        anchors.margins: 4
        spacing: 4

        Repeater {
            model: selector.options

            delegate: Rectangle {
                id: pill
                required property var modelData
                readonly property bool active: modelData.value === selector.current

                width: (pills.width - pills.spacing * (selector.options.length - 1)) / selector.options.length
                height: pills.height
                radius: Theme.radiusSmall
                color: active ? Theme.accentBg : pillMouse.containsMouse ? Theme.hover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: pill.modelData.label
                    color: pill.active ? Theme.accent : Theme.textSecondary
                    font.family: Theme.sansFont
                    font.pixelSize: Theme.fontSize
                    font.weight: pill.active ? Font.Medium : Font.Normal
                }

                MouseArea {
                    id: pillMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: selector.selected(pill.modelData.value)
                }
            }
        }
    }
}
