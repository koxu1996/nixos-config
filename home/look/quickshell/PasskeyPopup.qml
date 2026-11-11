// PasskeyPopup.qml: a linux-passkey approval (PasskeyAgent) under the Touch ID chip. Opens by
// itself on the screen that was focused when the request came in: what is asked, by which
// browser for which site, the account to use (a choice when the site has several of your
// passkeys), then "Touch the fingerprint sensor" until the daemon is done. Closing it any way
// but the main button (Esc, Cancel, a click elsewhere) denies the request.
// Keys: Enter approves, Up/Down pick the account, Esc denies.
import QtQuick
import QtQuick.Effects
import Quickshell

BarPopup {
    id: popup
    align: "right"

    // The FingerprintChip's screen, to open only where the request belongs.
    property string screenName: ""

    readonly property int shadowPad: 18
    readonly property var ask: PasskeyAgent.ask
    readonly property string stage: PasskeyAgent.stage
    property int selected: 0

    function show() {
        PopupManager.opened("passkey");
        visible = true;
        fadeInDelay.restart();
    }

    // Closing by hand (Esc, Cancel, outside click) answers the request: deny.
    function close() {
        fadeInDelay.stop();
        if (open && PasskeyAgent.open && stage !== "sent") PasskeyAgent.deny();
        hide();
    }

    function hide() {
        open = false;
        PopupManager.closed("passkey");
        hideAfterFade.restart();
    }

    function approve() {
        const accounts = ask?.accounts ?? [];
        PasskeyAgent.approve(accounts.length ? accounts[selected].id : "");
    }

    Connections {
        target: PasskeyAgent
        function onAskChanged() {
            if (PasskeyAgent.ask && PasskeyAgent.screenName === popup.screenName) {
                popup.selected = 0;
                popup.show();
            } else if (!PasskeyAgent.ask && popup.visible) {
                popup.hide();
            }
        }
    }

    // Only one bar popup at a time; another one opening counts as a click elsewhere.
    Connections {
        target: PopupManager
        function onCurrentChanged() { if (popup.visible && PopupManager.current !== "passkey") popup.close(); }
    }

    cardWidth: card.width + shadowPad
    cardHeight: card.height + shadowPad
    color: "transparent"
    visible: false

    Timer { id: fadeInDelay; interval: 16; onTriggered: { popup.open = true; card.forceActiveFocus(); } }
    Timer { id: hideAfterFade; interval: Theme.durationNormal; onTriggered: if (!popup.open) popup.visible = false }

    // Wording per operation: [title, body, main button].
    function wording() {
        const rp = ask?.rp ?? "";
        switch (ask?.op) {
        case "register": return [`Create a passkey for ${rp}`, "It stays in this computer's secure hardware.", "Create"];
        case "already-registered": return [`${rp} already has a passkey`, "This computer is already registered with this account. Nothing new is created.", "OK"];
        case "sign-in": return [`Sign in to ${rp}`, "", "Sign in"];
        case "select": return ["Use this security key?", "The browser asks which security key to use. Nothing is created.", "Select"];
        case "reset": return ["Reset the authenticator?", "This permanently deletes all passkeys on this computer.", "Reset"];
        case "u2f-register": return ["Register this security key", "A site asks to register this key (legacy U2F).", "Register"];
        case "u2f-sign-in": return ["Sign in with this security key", "A site asks to use this key (legacy U2F).", "Sign in"];
        default: return ["Use your passkey?", "", "Confirm"];
        }
    }

    RectangularShadow {
        anchors.fill: card
        opacity: card.opacity
        scale: card.scale
        transformOrigin: Item.TopRight
        radius: card.radius
        offset: Qt.vector2d(0, 4)
        blur: 14
        color: Theme.shadow
    }

    Rectangle {
        id: card

        x: popup.shadowPad
        width: 320
        height: (body.item ? body.item.implicitHeight : 0) + Theme.popupPadding * 2
        radius: Theme.radiusLarge
        color: Theme.raised
        border.width: Theme.borderWidth
        border.color: Theme.border

        focus: true
        Keys.onEscapePressed: popup.close()
        Keys.onReturnPressed: if (popup.stage === "ask") popup.approve()
        Keys.onEnterPressed: if (popup.stage === "ask") popup.approve()
        Keys.onUpPressed: popup.selected = Math.max(0, popup.selected - 1)
        Keys.onDownPressed: popup.selected = Math.min((popup.ask?.accounts?.length ?? 1) - 1, popup.selected + 1)

        transformOrigin: Item.TopRight
        opacity: popup.open ? 1 : 0
        scale: popup.open ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }

        Loader {
            id: body
            x: Theme.popupPadding
            y: Theme.popupPadding
            width: card.width - Theme.popupPadding * 2
            active: popup.visible && popup.ask !== null
            sourceComponent: popup.stage === "finger" ? fingerPage : askPage
        }
    }

    // ---- The request ------------------------------------------------------------------------
    Component {
        id: askPage

        Column {
            id: page
            spacing: 10
            readonly property var words: popup.wording()

            Row {
                spacing: 10

                AppGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    kind: "key"
                    size: 18
                    color: Theme.accent
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: 320 - Theme.popupPadding * 2 - 28
                        text: page.words[0]
                        elide: Text.ElideRight
                        color: Theme.textPrimary
                        font.family: Theme.sansFont
                        font.pixelSize: Theme.fontSizeLarge
                    }

                    // Who asks: "Brave · accounts.google.com".
                    Text {
                        visible: text !== ""
                        text: [popup.ask?.app, (popup.ask?.origin ?? "").replace(/^[a-z]+:\/\//, "")]
                            .filter(s => s).join(" · ")
                        color: Theme.textSecondary
                        font.family: Theme.monoFont
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            // The account: a choice for a sign-in, the one being registered otherwise.
            Column {
                width: parent.width
                spacing: 2
                visible: rows.count > 0

                Repeater {
                    id: rows
                    model: popup.ask?.op === "sign-in" ? (popup.ask?.accounts ?? [])
                        : popup.ask?.user ? [popup.ask.user] : []

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool choice: popup.ask?.op === "sign-in"
                        readonly property bool chosen: choice && popup.selected === index

                        width: parent.width
                        height: 40
                        radius: Theme.radius
                        color: chosen ? Theme.accentBg : rowMouse.containsMouse && choice ? Theme.raisedHigh : Theme.inset
                        border.width: Theme.borderWidth
                        border.color: chosen ? Theme.alpha(Theme.accent, 0.4) : Theme.borderSubtle

                        Column {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 44

                            Text {
                                width: parent.width
                                text: row.modelData.name || row.modelData.displayName || "Passkey"
                                elide: Text.ElideRight
                                color: row.chosen ? Theme.accent : Theme.textPrimary
                                font.family: Theme.sansFont
                                font.pixelSize: Theme.fontSizeTitle
                            }

                            Text {
                                width: parent.width
                                visible: !!row.modelData.displayName && row.modelData.displayName !== row.modelData.name
                                text: row.modelData.displayName ?? ""
                                elide: Text.ElideRight
                                color: Theme.textSecondary
                                font.family: Theme.sansFont
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }

                        AppGlyph {
                            visible: row.chosen && rows.count > 1
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            kind: "check"
                            size: 14
                            color: Theme.accent
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            enabled: row.choice
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: popup.selected = row.index
                            onDoubleClicked: { popup.selected = row.index; popup.approve(); }
                        }
                    }
                }
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: [page.words[1], popup.ask?.fingerprint ? "Then touch the fingerprint sensor." : ""]
                    .filter(s => s).join(" ")
                wrapMode: Text.WordWrap
                color: Theme.textSecondary
                font.family: Theme.sansFont
                font.pixelSize: Theme.fontSize
            }

            Item {
                width: parent.width
                height: 30

                PopupButton {
                    visible: popup.ask?.elsewhere ?? false
                    anchors.left: parent.left
                    text: "Another device"
                    flat: true
                    onClicked: PasskeyAgent.elsewhere()
                }

                Row {
                    anchors.right: parent.right
                    spacing: 6

                    PopupButton {
                        text: "Cancel"
                        onClicked: popup.close()
                    }

                    PopupButton {
                        text: page.words[2]
                        primary: true
                        destructive: popup.ask?.op === "reset"
                        enabled: popup.stage === "ask"
                        onClicked: popup.approve()
                    }
                }
            }
        }
    }

    // ---- After an approve: the finger -------------------------------------------------------
    Component {
        id: fingerPage

        Column {
            spacing: 10

            Row {
                spacing: 10

                AppGlyph {
                    id: glyph
                    anchors.verticalCenter: parent.verticalCenter
                    kind: PasskeyAgent.fingerState === "match" ? "check" : "fingerprint"
                    size: 18
                    color: PasskeyAgent.fingerState === "no-match" || PasskeyAgent.fingerState === "error"
                        ? Theme.error : Theme.accent

                    // Breathes while waiting for the finger (only while the popup shows it).
                    SequentialAnimation on opacity {
                        running: popup.visible && PasskeyAgent.stage === "finger" && PasskeyAgent.fingerState === "waiting"
                        loops: Animation.Infinite
                        onStopped: glyph.opacity = 1
                        NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: "Touch the fingerprint sensor"
                        color: Theme.textPrimary
                        font.family: Theme.sansFont
                        font.pixelSize: Theme.fontSizeLarge
                    }

                    Text {
                        text: ({
                            "waiting": `To ${popup.ask?.op === "register" ? "create the passkey for" : "sign in to"} ${popup.ask?.rp ?? ""}`,
                            "no-match": "Not recognized. Try again.",
                            "match": "Recognized",
                            "error": "The fingerprint check failed.",
                        })[PasskeyAgent.fingerState] ?? ""
                        color: PasskeyAgent.fingerState === "no-match" || PasskeyAgent.fingerState === "error"
                            ? Theme.error : Theme.textSecondary
                        font.family: Theme.sansFont
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            Item {
                width: parent.width
                height: 30

                PopupButton {
                    anchors.right: parent.right
                    text: "Cancel"
                    onClicked: popup.close()
                }
            }
        }
    }
}
