// FingerprintChip.qml: shown only while a fingerprint check runs (sudo, polkit, passkeys;
// FingerprintService), on a chip tinted in the state's colour:
//   waiting  lime fingerprint, pulsing, "Touch ID"      reading  lime, steady, "Reading…"
//   retry    amber, the reason ("Try again", …)          nomatch / error  coral
//   matched  lime check mark, "Done"
// Each result shows for a moment, then the chip follows the check again or hides.
import QtQuick

Item {
    id: root

    readonly property string status: FingerprintService.status
    readonly property color tone: status === "retry" ? Theme.warning
        : status === "nomatch" || status === "error" ? Theme.error
        : Theme.accent

    visible: status !== "idle"
    implicitWidth: visible ? chip.implicitWidth : 0
    implicitHeight: chip.implicitHeight

    Rectangle {
        id: chip

        implicitWidth: row.implicitWidth + Theme.barChipPadding * 2
        implicitHeight: Theme.barChipHeight
        radius: Theme.radiusSmall
        color: Theme.alpha(root.tone, 0.14)
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6

            AppGlyph {
                id: glyph
                anchors.verticalCenter: parent.verticalCenter
                kind: root.status === "matched" ? "check"
                    : root.status === "nomatch" || root.status === "error" ? "close"
                    : "fingerprint"
                size: Theme.barIconSize
                color: root.tone

                // Breathes while waiting for a finger; steady otherwise.
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
                text: ({
                    waiting: "Touch ID",
                    reading: "Reading…",
                    matched: "Done",
                })[root.status] ?? FingerprintService.flashText
                color: root.tone
                font.family: Theme.sansFont
                font.pixelSize: Theme.fontSize
                font.weight: Font.Medium
            }
        }
    }
}
