// FingerprintChip.qml: shown only while a fingerprint check waits for a finger (sudo, polkit,
// passkeys; FingerprintService): a pulsing lime fingerprint and "Touch ID" on a lime-tinted
// chip, then a check mark for a moment once the finger matched. Hidden otherwise.
import QtQuick

Item {
    id: root

    readonly property string status: FingerprintService.status

    visible: status !== "idle"
    implicitWidth: visible ? chip.implicitWidth : 0
    implicitHeight: chip.implicitHeight

    Rectangle {
        id: chip

        implicitWidth: row.implicitWidth + Theme.barChipPadding * 2
        implicitHeight: Theme.barChipHeight
        radius: Theme.radiusSmall
        color: Theme.accentBg

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6

            AppGlyph {
                id: glyph
                anchors.verticalCenter: parent.verticalCenter
                kind: root.status === "matched" ? "check" : "fingerprint"
                size: Theme.barIconSize
                color: Theme.accent

                // Breathes while waiting; steady on the check mark.
                SequentialAnimation on opacity {
                    running: root.status === "waiting"
                    loops: Animation.Infinite
                    onStopped: glyph.opacity = 1
                    NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.status === "matched" ? "Done" : "Touch ID"
                color: Theme.accent
                font.family: Theme.sansFont
                font.pixelSize: Theme.fontSize
                font.weight: Font.Medium
            }
        }
    }
}
