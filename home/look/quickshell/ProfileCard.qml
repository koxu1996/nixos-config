// ProfileCard.qml: one read-only schedule profile in the Glow popup.
// `profile` is an entry of GlowService.schedule.
import QtQuick

Rectangle {
    id: card

    property var profile
    property bool active: false

    implicitHeight: row.implicitHeight + 18
    radius: Theme.radius
    color: active ? Theme.raised : Theme.inset
    border.width: Theme.borderWidth
    border.color: active ? Theme.accent : Theme.borderSubtle

    Row {
        id: row
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 24
        spacing: 10

        // Dot in the profile's light colour.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 12
            height: 12
            radius: 6
            color: GlowService.kelvinColor(card.profile.temperature)
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: row.width - 12 - badge.width - timeChip.width - row.spacing * 3
            spacing: 2

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: card.profile.name
                color: Theme.textPrimary
                font.family: Theme.sansFont
                font.pixelSize: Theme.fontSize
                font.weight: Font.Medium
            }

            Text {
                text: `${card.profile.temperature} K`
                color: Theme.textSecondary
                font.family: Theme.monoFont
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        // "now" badge, active profile only (keeps its slot so times stay aligned).
        Rectangle {
            id: badge
            anchors.verticalCenter: parent.verticalCenter
            width: badgeText.implicitWidth + 12
            height: badgeText.implicitHeight + 4
            radius: Theme.radiusSmall
            color: Theme.accentBg
            opacity: card.active ? 1 : 0

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: "now"
                color: Theme.accent
                font.family: Theme.monoFont
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        // Start time (sunset profiles show the computed time, no label).
        Rectangle {
            id: timeChip
            anchors.verticalCenter: parent.verticalCenter
            width: timeText.implicitWidth + 14
            height: timeText.implicitHeight + 6
            radius: Theme.radiusSmall
            color: card.active ? Theme.raisedHigh : Theme.raised

            Text {
                id: timeText
                anchors.centerIn: parent
                text: card.profile.clock
                color: Theme.textPrimary
                font.family: Theme.monoFont
                font.pixelSize: Theme.fontSize
                font.features: { "tnum": 1 }
            }
        }
    }
}
