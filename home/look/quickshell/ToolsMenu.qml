// ToolsMenu.qml: the wrench chip's menu, built from ToolsService.categories: a header per
// category (glyph + title) and a row per tool (glyph, title, subtitle). Clicking a tool
// closes the menu, then runs it. Opened from ToolsChip.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland

BarPopup {
    id: popup
    align: "right"

    readonly property int shadowPad: 18

    function toggle() { if (open) close(); else if (!PopupManager.justClosed("tools")) show(); }

    function show() {
        PopupManager.opened("tools");
        visible = true;
        fadeInDelay.restart();
    }

    function close() {
        fadeInDelay.stop();
        open = false;
        PopupManager.closed("tools");
        hideAfterFade.restart();
    }

    function activate(action) {
        close();
        ToolsService.run(action);
    }

    // Only one bar popup at a time.
    Connections {
        target: PopupManager
        function onCurrentChanged() { if (popup.visible && PopupManager.current !== "tools") popup.close(); }
    }

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
        transformOrigin: Item.TopRight
        radius: card.radius
        offset: Qt.vector2d(0, 4)
        blur: 14
        color: Theme.shadow
    }

    Rectangle {
        id: card

        x: popup.shadowPad
        width: 240
        height: content.implicitHeight + 12
        radius: Theme.radiusLarge
        color: Theme.raised
        border.width: Theme.borderWidth
        border.color: Theme.border

        focus: true
        Keys.onEscapePressed: popup.close()

        transformOrigin: Item.TopRight
        opacity: popup.open ? 1 : 0
        scale: popup.open ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }

        Column {
            id: content
            x: 6
            y: 6
            width: parent.width - 12
            spacing: 2

            Repeater {
                model: ToolsService.categories

                delegate: Column {
                    id: category
                    required property var modelData
                    required property int index

                    width: content.width
                    spacing: 2

                    // Divider between categories.
                    Item {
                        visible: category.index > 0
                        width: parent.width
                        height: 9

                        Rectangle {
                            x: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 8
                            height: 1
                            color: Theme.borderSubtle
                        }
                    }

                    // Header.
                    Row {
                        leftPadding: 10
                        topPadding: 8
                        bottomPadding: 4
                        spacing: 8

                        AppGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            kind: category.modelData.icon
                            size: 12
                            color: Theme.textSecondary
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: category.modelData.title
                            color: Theme.textSecondary
                            font.family: Theme.monoFont
                            font.pixelSize: Theme.fontSizeSmall
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.6
                        }
                    }

                    Repeater {
                        model: category.modelData.items

                        delegate: Rectangle {
                            id: tool
                            required property var modelData

                            width: category.width
                            height: 46
                            radius: Theme.radius
                            color: toolMouse.containsMouse ? Theme.raisedHigh : "transparent"

                            Row {
                                x: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12

                                AppGlyph {
                                    anchors.verticalCenter: parent.verticalCenter
                                    kind: tool.modelData.icon
                                    size: 16
                                    color: Theme.textPrimary
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: tool.modelData.title
                                        color: Theme.textPrimary
                                        font.family: Theme.sansFont
                                        font.pixelSize: Theme.fontSizeTitle
                                    }

                                    Text {
                                        text: tool.modelData.subtitle
                                        color: Theme.textSecondary
                                        font.family: Theme.monoFont
                                        font.pixelSize: Theme.fontSizeSmall
                                    }
                                }
                            }

                            MouseArea {
                                id: toolMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: popup.activate(tool.modelData.action)
                            }
                        }
                    }
                }
            }
        }
    }
}
