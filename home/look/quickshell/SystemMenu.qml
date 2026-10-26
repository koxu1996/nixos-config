// SystemMenu.qml: the snowflake chip's menu: Applications and Update system, then Reboot and
// Power off behind an inline confirmation. Up/Down move a highlight, Enter activates it, Escape backs out of
// the confirmation and then closes. Opened from SystemChip; reset to the plain rows on open.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland

BarPopup {
    id: popup
    align: "left"

    // Keyboard/hover highlight over the rows (0 Applications, 1 Update system, 2 Reboot,
    // 3 Power off), -1 none.
    property int highlight: -1
    // "" for the rows, "reboot" or "poweroff" while confirming.
    property string confirming: ""
    // In the confirmation: 0 = Cancel (the default), 1 = the confirm button.
    property int confirmFocus: 0

    readonly property int shadowPad: 18

    function toggle() { if (open) close(); else if (!PopupManager.justClosed("system")) show(); }

    function show() {
        highlight = -1;
        confirming = "";
        confirmFocus = 0;
        PopupManager.opened("system");
        visible = true;
        fadeInDelay.restart();
    }

    function close() {
        fadeInDelay.stop();
        open = false;
        PopupManager.closed("system");
        hideAfterFade.restart();
    }

    // Only one bar popup at a time.
    Connections {
        target: PopupManager
        function onCurrentChanged() { if (popup.visible && PopupManager.current !== "system") popup.close(); }
    }

    function activate(i) {
        if (i === 0) {
            close();
            LauncherService.toggleRequested();
        } else if (i === 1) {
            close();
            // home/nixos-update.nix: pull ~/nixos and switch; the terminal shows the progress.
            Quickshell.execDetached(["alacritty", "--class", "nixos-update", "--title", "Update system",
                                     "-e", "nixos-update"]);
        } else if (i === 2 || i === 3) {
            confirming = i === 2 ? "reboot" : "poweroff";
            confirmFocus = 0;
        }
    }

    function confirm() {
        const action = confirming;
        close();
        Quickshell.execDetached(["systemctl", action]);
    }

    function cancelConfirm() {
        highlight = confirming === "reboot" ? 2 : 3;
        confirming = "";
    }

    // Extra room right and below for the drop shadow; only the card takes input.
    cardWidth: card.width + shadowPad
    cardHeight: card.height + shadowPad
    color: "transparent"
    visible: false

    // Map the window with the card still transparent and start the fade-in a frame
    // later, so the window's very first frame shows nothing (no stale-frame flash).
    Timer { id: fadeInDelay; interval: 16; onTriggered: { popup.open = true; card.forceActiveFocus(); } }

    Timer { id: hideAfterFade; interval: Theme.durationNormal; onTriggered: if (!popup.open) popup.visible = false }

    RectangularShadow {
        anchors.fill: card
        opacity: card.opacity
        scale: card.scale
        transformOrigin: Item.TopLeft
        radius: card.radius
        offset: Qt.vector2d(0, 4)
        blur: 14
        color: Theme.shadow
    }

    Rectangle {
        id: card

        width: 220
        height: content.implicitHeight + 12
        radius: Theme.radiusLarge
        color: Theme.raised
        border.width: Theme.borderWidth
        border.color: Theme.border

        focus: true
        Keys.onPressed: event => {
            if (popup.confirming !== "") {
                if (event.key === Qt.Key_Escape) popup.cancelConfirm();
                else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right
                         || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
                    popup.confirmFocus = 1 - popup.confirmFocus;
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    popup.confirmFocus === 0 ? popup.cancelConfirm() : popup.confirm();
                else return;
            } else {
                if (event.key === Qt.Key_Escape) popup.close();
                else if (event.key === Qt.Key_Down) popup.highlight = Math.min(3, popup.highlight + 1);
                else if (event.key === Qt.Key_Up) popup.highlight = Math.max(0, popup.highlight - 1);
                else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && popup.highlight >= 0)
                    popup.activate(popup.highlight);
                else return;
            }
            event.accepted = true;
        }

        transformOrigin: Item.TopLeft
        opacity: popup.open ? 1 : 0
        scale: popup.open ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }

        Column {
            id: content
            x: 6
            y: 6
            width: parent.width - 12
            spacing: 6

            // ---- 1. Applications, Update system ----
            MenuRow {
                menu: popup
                width: parent.width
                index: 0
                glyph: "grid"
                label: "Applications"
            }

            MenuRow {
                menu: popup
                width: parent.width
                index: 1
                glyph: "sync"
                label: "Update system"
            }

            // ---- 2. Divider ----
            Item {
                width: parent.width
                height: 1

                Rectangle {
                    x: 4
                    width: parent.width - 8
                    height: 1
                    color: Theme.borderSubtle
                }
            }

            // ---- 3. Reboot / Power off ----
            Column {
                visible: popup.confirming === ""
                width: parent.width
                spacing: 2

                MenuRow {
                    menu: popup
                    width: parent.width
                    index: 2
                    glyph: "reboot"
                    label: "Reboot"
                    danger: true
                }

                MenuRow {
                    menu: popup
                    width: parent.width
                    index: 3
                    glyph: "power"
                    label: "Power off"
                    danger: true
                }
            }

            // ---- Confirmation (replaces the two rows) ----
            Column {
                visible: popup.confirming !== ""
                width: parent.width
                spacing: 8

                Text {
                    leftPadding: 6
                    rightPadding: 6
                    text: popup.confirming === "reboot" ? "Reboot now?" : "Power off now?"
                    color: Theme.textPrimary
                    font.family: Theme.sansFont
                    font.pixelSize: Theme.fontSizeTitle
                }

                Row {
                    width: parent.width
                    spacing: 6

                    ConfirmButton {
                        width: (parent.width - parent.spacing) / 2
                        label: "Cancel"
                        focused: popup.confirmFocus === 0
                        onClicked: popup.cancelConfirm()
                    }

                    ConfirmButton {
                        width: (parent.width - parent.spacing) / 2
                        label: popup.confirming === "reboot" ? "Reboot" : "Power off"
                        danger: true
                        focused: popup.confirmFocus === 1
                        onClicked: popup.confirm()
                    }
                }
            }
        }
    }

    // A menu row: glyph + label; hover and the keyboard highlight share one background.
    component MenuRow: Rectangle {
        id: row

        property var menu // the popup; inline components can't see its id
        property int index
        property string glyph
        property string label
        property bool danger: false
        readonly property bool lit: menu.highlight === index

        height: 34
        radius: Theme.radius
        color: !lit ? "transparent" : danger ? Theme.alpha(Theme.error, 0.1) : Theme.raisedHigh

        readonly property color fg: danger ? (lit ? Theme.error : Theme.textSecondary) : Theme.textPrimary

        Row {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            AppGlyph {
                anchors.verticalCenter: parent.verticalCenter
                kind: row.glyph
                size: 14
                color: row.fg
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: row.label
                color: row.fg
                font.family: Theme.sansFont
                font.pixelSize: Theme.fontSizeTitle
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: row.menu.highlight = row.index
            onExited: if (row.menu.highlight === row.index) row.menu.highlight = -1
            onClicked: row.menu.activate(row.index)
        }
    }

    // Cancel (neutral) or the destructive confirm button. `focused` marks the Enter target.
    component ConfirmButton: Rectangle {
        id: button

        property string label
        property bool danger: false
        property bool focused: false
        signal clicked()

        height: 30
        radius: Theme.radiusSmall
        color: danger ? Theme.error : Theme.raisedHigh
        border.width: focused ? 2 : (danger ? 0 : Theme.borderWidth)
        border.color: focused ? Theme.alpha(Theme.accent, 0.55) : Theme.border

        Text {
            anchors.centerIn: parent
            text: button.label
            color: button.danger ? Theme.textOnAccent : Theme.textPrimary
            font.family: Theme.sansFont
            font.pixelSize: Theme.fontSize
            font.weight: button.danger ? Font.Medium : Font.Normal
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
