// LauncherSearch.qml: the launcher's search field. Keeps keyboard focus while the launcher
// is open and turns navigation keys into signals; everything else is typed into the field.
import QtQuick

Item {
    id: root

    property alias text: input.text

    signal moved(int delta)
    signal accepted()
    signal escaped()

    function clear() { input.text = ""; }
    function focusInput() { input.forceActiveFocus(); }

    implicitHeight: 58

    // Faint 3px lime glow around the field while focused.
    Rectangle {
        anchors.fill: field
        anchors.margins: -3
        radius: field.radius + 3
        color: "transparent"
        border.width: 3
        border.color: Theme.alpha(Theme.accent, 0.08)
        visible: input.activeFocus
    }

    Rectangle {
        id: field
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.inset
        border.width: Theme.borderWidth
        border.color: input.activeFocus ? Theme.alpha(Theme.accent, 0.55) : Theme.borderSubtle

        AppGlyph {
            id: glyph
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            kind: "search"
            size: 20
            color: Theme.accent
        }

        TextInput {
            id: input
            anchors.left: glyph.right
            anchors.leftMargin: 14
            anchors.right: escChip.left
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            color: Theme.textPrimary
            selectionColor: Theme.accentBg
            selectedTextColor: Theme.accent
            font.family: Theme.sansFont
            font.pixelSize: 18

            cursorDelegate: Rectangle {
                width: 2
                color: Theme.accent
                visible: input.activeFocus

                SequentialAnimation on opacity {
                    running: input.activeFocus
                    loops: Animation.Infinite
                    PropertyAction { value: 1 }
                    PauseAnimation { duration: 530 }
                    PropertyAction { value: 0 }
                    PauseAnimation { duration: 530 }
                }
            }

            Keys.onPressed: event => {
                const ctrl = event.modifiers & Qt.ControlModifier;
                const shift = event.modifiers & Qt.ShiftModifier;
                if (event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !shift) || (ctrl && event.key === Qt.Key_N))
                    root.moved(1);
                else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab
                         || (event.key === Qt.Key_Tab && shift) || (ctrl && event.key === Qt.Key_K))
                    root.moved(-1);
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    root.accepted();
                else if (event.key === Qt.Key_Escape)
                    root.escaped();
                else
                    return;
                event.accepted = true;
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                text: "Search apps and commands"
                color: Theme.textDisabled
                font: input.font
            }
        }

        Rectangle {
            id: escChip
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: escText.implicitWidth + 12
            implicitHeight: escText.implicitHeight + 6
            radius: Theme.radiusSmall
            color: "transparent"
            border.width: Theme.borderWidth
            border.color: Theme.border

            Text {
                id: escText
                anchors.centerIn: parent
                text: "esc"
                color: Theme.textDisabled
                font.family: Theme.monoFont
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }
}
