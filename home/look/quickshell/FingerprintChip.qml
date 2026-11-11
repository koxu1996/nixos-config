// FingerprintChip.qml: shown only while a fingerprint check runs (sudo, polkit, passkeys;
// FingerprintService), on a chip tinted in the state's colour:
//   waiting  lime fingerprint, pulsing, "Touch ID"      reading  lime, steady, "Reading…"
//   retry    amber, the reason ("Try again", …)          nomatch / error  coral
//   matched  lime check mark, "Done"
// Each result shows for a moment, then the chip follows the check again or hides.
// Also while a linux-passkey approval is open (PasskeyAgent): "Passkey" with a key, and the
// request in PasskeyPopup below it; a click brings that popup back.
import QtQuick
import Quickshell

Item {
    id: root

    // The finger first (fprintd), then a passkey request: its fingerprint step as the daemon
    // reports it (hosts without fprintd), or waiting for an answer.
    readonly property string status: FingerprintService.status !== "idle" ? FingerprintService.status
        : PasskeyAgent.stage === "finger" ? ({
            "waiting": "waiting", "no-match": "nomatch", "match": "matched", "error": "error",
        })[PasskeyAgent.fingerState] ?? "waiting"
        : PasskeyAgent.open ? "passkey" : "idle"
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
        color: Theme.alpha(root.tone, chipMouse.containsMouse || popup.open ? 0.24 : 0.14)
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
                    : root.status === "passkey" ? "key"
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
                    passkey: "Passkey",
                    reading: "Reading…",
                    matched: "Done",
                })[root.status] ?? (FingerprintService.flashText
                    || (root.status === "nomatch" ? "No match" : root.status === "error" ? "Sensor error" : ""))
                color: root.tone
                font.family: Theme.sansFont
                font.pixelSize: Theme.fontSize
                font.weight: Font.Medium
            }
        }
    }

    MouseArea {
        id: chipMouse
        anchors.fill: chip
        enabled: PasskeyAgent.open
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (!popup.visible) popup.show()
    }

    PasskeyPopup {
        id: popup
        anchorItem: chip
        screenName: root.QsWindow.window?.screen?.name ?? ""
    }
}
