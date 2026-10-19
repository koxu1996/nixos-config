// NotificationCard.qml: one active notification (centre) or its toast body (`toast: true`).
// Top row: icon tile · app name (+ Critical chip) / summary / body · relative time · close.
// Below, indented to the text: progress (`value` hint), inline reply, action buttons.
// Clicking the card invokes the "default" action when the app provides one.
import QtQuick
import Quickshell.Widgets

Rectangle {
    id: card

    property var notification
    property bool toast: false

    readonly property var n: notification
    readonly property bool critical: NotificationService.isCritical(n)
    readonly property int pad: toast ? 14 : 12
    readonly property int tileSize: toast ? 32 : 28
    // A picture (inline image data, or an image / image-path hint that is a file, e.g. a
    // screenshot) is shown as a 64×40 thumbnail instead of the icon tile. Icon names sent
    // as image-path stay icons.
    readonly property string thumbUrl: {
        const h = n?.hints ?? {};
        for (const c of [n?.image, h["image-path"], h["image_path"]]) {
            const v = String(c ?? "");
            if (v.startsWith("image:") || v.startsWith("file:")) return v;
            if (v.startsWith("/")) return "file://" + v;
        }
        return "";
    }
    readonly property bool hasThumb: thumbUrl !== "" && thumb.status !== Image.Error
    readonly property int indent: (hasThumb ? 64 : tileSize) + 10
    readonly property string iconUrl: NotificationService.iconSource(n?.appIcon || n?.image || "")
    readonly property real progress: {
        const v = n?.hints?.value;
        return v === undefined || v === null || isNaN(Number(v)) ? -1 : Math.max(0, Math.min(100, Number(v)));
    }
    readonly property var buttons: (n?.actions ?? []).filter(a => a.identifier !== "default")
    readonly property bool hasDefault: (n?.actions ?? []).some(a => a.identifier === "default")

    implicitHeight: content.implicitHeight + pad * 2
    radius: toast ? Theme.radiusLarge : Theme.radius
    color: toast ? Theme.raised : critical ? Theme.alpha(Theme.error, 0.05) : Theme.inset
    border.width: Theme.borderWidth
    border.color: critical ? Theme.alpha(Theme.error, 0.55) : toast ? Theme.border : Theme.borderSubtle

    MouseArea {
        anchors.fill: parent
        cursorShape: card.hasDefault ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: NotificationService.invokeDefault(card.n)
    }

    Column {
        id: content
        x: card.pad
        y: card.pad
        width: parent.width - card.pad * 2
        spacing: 10

        // ---- Top row ----
        Item {
            width: parent.width
            implicitHeight: Math.max(card.hasThumb ? 40 : tile.height, text.implicitHeight)

            // Thumbnail (pictures, e.g. screenshots).
            Rectangle {
                visible: card.hasThumb
                width: 64
                height: 40
                radius: Theme.radiusSmall
                color: Theme.raisedHigh
                border.width: Theme.borderWidth
                border.color: Theme.border

                ClippingRectangle {
                    anchors.fill: parent
                    anchors.margins: Theme.borderWidth
                    radius: Theme.radiusSmall - Theme.borderWidth
                    color: "transparent"

                    Image {
                        id: thumb
                        anchors.fill: parent
                        source: card.thumbUrl
                        sourceSize: Qt.size(128, 80)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false // the region screenshot reuses one file name
                    }
                }
            }

            Rectangle {
                id: tile
                visible: !card.hasThumb
                width: card.tileSize
                height: card.tileSize
                radius: card.toast ? Theme.radius : Theme.radiusSmall
                color: card.critical ? Theme.alpha(Theme.error, 0.15) : Theme.raisedHigh

                Image {
                    id: appIcon
                    anchors.centerIn: parent
                    width: card.toast ? 20 : 18
                    height: width
                    sourceSize: Qt.size(width * 2, height * 2)
                    source: card.iconUrl
                    visible: status === Image.Ready
                }

                AppGlyph {
                    anchors.centerIn: parent
                    visible: appIcon.status !== Image.Ready
                    kind: "bell"
                    size: card.toast ? 16 : Theme.iconSize
                    color: card.critical ? Theme.error : Theme.textSecondary
                }
            }

            Column {
                id: text
                x: card.indent
                width: parent.width - card.indent - closeButton.width - 8
                spacing: 3

                Item {
                    width: parent.width
                    implicitHeight: appName.implicitHeight

                    Row {
                        spacing: 6

                        Text {
                            id: appName
                            text: card.n?.appName || "Notification"
                            color: Theme.textSecondary
                            font.family: Theme.sansFont
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Rectangle {
                            visible: card.critical
                            anchors.verticalCenter: parent.verticalCenter
                            width: criticalText.implicitWidth + 10
                            height: criticalText.implicitHeight + 2
                            radius: Theme.radiusSmall
                            color: Theme.alpha(Theme.error, 0.12)

                            Text {
                                id: criticalText
                                anchors.centerIn: parent
                                text: "Critical"
                                color: Theme.error
                                font.family: Theme.sansFont
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        text: NotificationService.relativeTime(NotificationService.arrivalOf(card.n))
                        color: Theme.textDisabled
                        font.family: Theme.monoFont
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: card.n?.summary ?? ""
                    color: Theme.textPrimary
                    font.family: Theme.sansFont
                    font.pixelSize: Theme.fontSizeTitle
                    font.weight: Font.Medium
                }

                Text {
                    visible: text !== ""
                    width: parent.width
                    wrapMode: Text.Wrap
                    maximumLineCount: card.toast ? 4 : 8
                    elide: Text.ElideRight
                    textFormat: Text.StyledText
                    text: card.n?.body ?? ""
                    color: Theme.textSecondary
                    linkColor: Theme.accent
                    lineHeight: 1.45
                    font.family: Theme.sansFont
                    font.pixelSize: Theme.fontSize
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
            }

            Rectangle {
                id: closeButton
                anchors.right: parent.right
                width: 22
                height: 22
                radius: Theme.radiusSmall
                color: closeMouse.containsMouse ? Theme.hover : "transparent"

                AppGlyph {
                    anchors.centerIn: parent
                    kind: "close"
                    size: 12
                    color: Theme.textSecondary
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationService.dismiss(card.n)
                }
            }
        }

        // ---- Progress (`value` hint) ----
        Item {
            visible: card.progress >= 0
            x: card.indent
            width: parent.width - card.indent
            implicitHeight: percent.implicitHeight

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - percent.width - 10
                height: 4
                radius: 2
                color: Theme.track

                Rectangle {
                    width: parent.width * card.progress / 100
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent
                }
            }

            Text {
                id: percent
                anchors.right: parent.right
                text: `${Math.round(card.progress)}%`
                color: Theme.textSecondary
                font.family: Theme.monoFont
                font.pixelSize: Theme.fontSizeSmall
                font.features: { "tnum": 1 }
            }
        }

        // ---- Inline reply ----
        Row {
            visible: card.n?.hasInlineReply ?? false
            x: card.indent
            width: parent.width - card.indent
            spacing: 6

            function send() {
                if (replyInput.text.trim() === "" || !card.n) return;
                card.n.sendInlineReply(replyInput.text);
                replyInput.text = "";
            }

            Rectangle {
                width: parent.width - sendButton.width - parent.spacing
                height: 28
                radius: Theme.radiusSmall
                color: Theme.raisedHigh
                border.width: Theme.borderWidth
                border.color: replyInput.activeFocus ? Theme.alpha(Theme.accent, 0.5) : Theme.border

                TextInput {
                    id: replyInput
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: Theme.textPrimary
                    selectionColor: Theme.accentBg
                    font.family: Theme.sansFont
                    font.pixelSize: Theme.fontSize
                    onAccepted: parent.parent.send()
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 8
                    visible: replyInput.text === ""
                    text: card.n?.inlineReplyPlaceholder || `Reply to ${card.n?.summary ?? ""}`
                    color: Theme.textDisabled
                    font.family: Theme.sansFont
                    font.pixelSize: Theme.fontSize
                }
            }

            Rectangle {
                id: sendButton
                width: sendText.implicitWidth + 20
                height: 28
                radius: Theme.radiusSmall
                color: Theme.accentBg

                Text {
                    id: sendText
                    anchors.centerIn: parent
                    text: "Send"
                    color: Theme.accent
                    font.family: Theme.sansFont
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.Medium
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.parent.send()
                }
            }
        }

        // ---- Actions ----
        Flow {
            visible: card.buttons.length > 0
            x: card.indent
            width: parent.width - card.indent
            spacing: 6

            Repeater {
                model: card.buttons

                delegate: Rectangle {
                    id: actionButton
                    required property var modelData
                    width: actionText.implicitWidth + 20
                    height: 28
                    radius: Theme.radiusSmall
                    color: actionMouse.containsMouse ? Theme.track : Theme.raisedHigh
                    border.width: Theme.borderWidth
                    border.color: Theme.border

                    Text {
                        id: actionText
                        anchors.centerIn: parent
                        text: actionButton.modelData.text
                        color: Theme.textPrimary
                        font.family: Theme.sansFont
                        font.pixelSize: Theme.fontSize
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: actionButton.modelData.invoke()
                    }
                }
            }
        }
    }
}
