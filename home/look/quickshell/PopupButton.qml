// PopupButton.qml: a text button inside a popup card. `primary`: the accent action (coral with
// `destructive`); `flat`: no background until hovered.
import QtQuick

Rectangle {
    id: button

    property string text
    property bool primary: false
    property bool destructive: false
    property bool flat: false
    signal clicked()

    readonly property color fill: destructive ? Theme.error : Theme.accent

    implicitWidth: label.implicitWidth + 24
    implicitHeight: 30
    radius: Theme.radiusSmall
    opacity: enabled ? 1 : 0.5
    color: primary ? (mouse.containsMouse ? Qt.lighter(fill, 1.08) : fill)
        : mouse.containsMouse ? Theme.raisedHigh
        : flat ? "transparent" : Theme.inset
    border.width: primary || flat ? 0 : Theme.borderWidth
    border.color: Theme.borderSubtle
    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

    Text {
        id: label
        anchors.centerIn: parent
        text: button.text
        color: button.primary ? Theme.textOnAccent : button.flat ? Theme.textSecondary : Theme.textPrimary
        font.family: Theme.sansFont
        font.pixelSize: Theme.fontSize
        font.weight: Font.Medium
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: button.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
