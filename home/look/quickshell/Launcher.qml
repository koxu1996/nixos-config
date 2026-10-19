// Launcher.qml: app launcher on the overlay layer of the focused screen, with a dim scrim.
// Pinned apps (launcher.json), then every command on PATH, fuzzy-filtered as you type;
// "Run <query> in a shell" when nothing matches. Data and launching: LauncherService.qml.
// Toggle: `quickshell ipc -c bar call launcher toggle` (Super+D in hyprland.nix).
// One instance in shell.qml (not per screen). Checked against Quickshell 0.3.0.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: launcher

    property bool shown: false
    // Dim backdrop behind the panel. Temporarily off; clicking outside the panel still closes.
    property bool dimBackdrop: false
    property string query: ""
    property int selected: 0

    readonly property var results: LauncherService.search(query)
    readonly property var pinnedResults: results.pinned
    readonly property var commandResults: results.commands
    readonly property bool fallback: query.trim() !== "" && pinnedResults.length === 0 && commandResults.length === 0
    readonly property int count: fallback ? 1 : pinnedResults.length + commandResults.length

    // New results start on the best match (the first pinned app for an empty query).
    onResultsChanged: select(results.best)

    function select(i) {
        selected = Math.max(0, Math.min(count - 1, i));
        Qt.callLater(revealSelected); // after the list has picked up new results
    }

    function revealSelected() {
        const c = selected - pinnedResults.length;
        if (c >= 0 && !fallback) commandList.positionViewAtIndex(c, ListView.Contain);
        else commandList.positionViewAtBeginning();
    }

    function activate(i) {
        if (fallback) LauncherService.run(query.trim());
        else if (i < pinnedResults.length) LauncherService.launchPinned(pinnedResults[i].app);
        else if (i - pinnedResults.length < commandResults.length) LauncherService.run(commandResults[i - pinnedResults.length].name);
        else return;
        close();
    }

    function open() {
        const monitor = Hyprland.focusedMonitor?.name;
        screen = Quickshell.screens.find(s => s.name === monitor) ?? Quickshell.screens[0];
        search.clear();
        query = "";
        select(0);
        LauncherService.refreshCommands();
        visible = true;
        shown = true;
        search.focusInput();
    }

    function close() {
        if (!shown) return;
        shown = false;
        hideAfterFade.restart();
    }

    function toggle() { shown ? close() : open(); }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcher.toggle(); }
    }

    Connections {
        target: LauncherService
        function onToggleRequested() { launcher.toggle(); }
    }

    Timer { id: hideAfterFade; interval: Theme.durationFast; onTriggered: if (!launcher.shown) launcher.visible = false }

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    visible: false

    Item {
        anchors.fill: parent
        opacity: launcher.shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: launcher.shown ? Theme.durationNormal : Theme.durationFast
                easing.type: Easing.OutCubic
            }
        }

        // Scrim: click to close.
        Rectangle {
            anchors.fill: parent
            color: launcher.dimBackdrop ? Theme.shadow : "transparent"

            MouseArea {
                anchors.fill: parent
                onClicked: launcher.close()
            }
        }

        RectangularShadow {
            anchors.fill: panel
            scale: panel.scale
            radius: panel.radius
            offset: Qt.vector2d(0, 10)
            blur: 40
            spread: 0
            color: Theme.shadow
        }

        Rectangle {
            id: panel

            anchors.centerIn: parent
            width: 640
            height: 520
            radius: Theme.radiusLarge
            color: Theme.raised
            border.width: Theme.borderWidth
            border.color: Theme.border

            transformOrigin: Item.Center
            scale: launcher.shown ? 1 : 0.94
            Behavior on scale { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }

            // Clicks inside the panel must not reach the scrim.
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.popupPadding
                spacing: Theme.popupSpacing

                // ---- 1. Search ----
                LauncherSearch {
                    id: search
                    Layout.fillWidth: true
                    onTextChanged: launcher.query = text
                    onMoved: delta => launcher.select(launcher.selected + delta)
                    onAccepted: launcher.activate(launcher.selected)
                    onEscaped: launcher.close()
                }

                // ---- 2. Pinned ----
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: launcher.pinnedResults.length > 0
                    spacing: 8

                    SectionLabel { text: "PINNED" }

                    Column {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: launcher.pinnedResults

                            delegate: PinnedRow {
                                required property var modelData
                                required property int index
                                width: parent.width
                                item: modelData
                                selected: !launcher.fallback && launcher.selected === index
                                onActivated: launcher.activate(index)
                            }
                        }
                    }
                }

                // ---- 3. Commands ----
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    Row {
                        spacing: 8

                        SectionLabel { id: commandsLabel; text: "COMMANDS" }

                        Text {
                            anchors.baseline: commandsLabel.baseline
                            text: launcher.query.trim() === ""
                                ? `${LauncherService.commands.length}`
                                : `${launcher.commandResults.length} of ${LauncherService.commands.length}`
                            color: Theme.textDisabled
                            font.family: Theme.monoFont
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    // No match: run the query in a shell.
                    Rectangle {
                        Layout.fillWidth: true
                        visible: launcher.fallback
                        implicitHeight: 34
                        radius: Theme.radiusSmall
                        color: Theme.accentBg

                        Row {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            AppGlyph {
                                anchors.verticalCenter: parent.verticalCenter
                                kind: "terminal"
                                size: 14
                                color: Theme.accent
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, panel.width - 120)
                                elide: Text.ElideRight
                                textFormat: Text.StyledText
                                text: `Run <font face="${Theme.monoFont}">${LauncherService.highlight(launcher.query.trim(), [])}</font> in a shell`
                                color: Theme.textPrimary
                                font.family: Theme.sansFont
                                font.pixelSize: Theme.fontSize
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "↵"
                            color: Theme.accent
                            font.family: Theme.monoFont
                            font.pixelSize: Theme.fontSize
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: launcher.activate(0)
                        }
                    }

                    ListView {
                        id: commandList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: !launcher.fallback
                        clip: true
                        reuseItems: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: launcher.commandResults

                        delegate: CommandRow {
                            required property var modelData
                            required property int index
                            width: commandList.width - 8 // room for the scrollbar
                            name: modelData.name
                            indices: modelData.indices
                            selected: launcher.selected === launcher.pinnedResults.length + index
                            onActivated: launcher.activate(launcher.pinnedResults.length + index)
                        }

                        // Thin scrollbar.
                        Rectangle {
                            anchors.right: parent.right
                            y: commandList.visibleArea.yPosition * commandList.height
                            width: 3
                            height: Math.max(20, commandList.visibleArea.heightRatio * commandList.height)
                            radius: 1.5
                            color: Theme.border
                            visible: commandList.visibleArea.heightRatio < 1
                        }
                    }
                }

                // ---- 4. Footer ----
                Column {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        width: parent.width
                        height: Theme.borderWidth
                        color: Theme.borderSubtle
                    }

                    Row {
                        spacing: 16

                        Repeater {
                            model: [["↑↓", "select"], ["↵", "launch"], ["esc", "close"]]

                            delegate: Text {
                                required property var modelData
                                textFormat: Text.StyledText
                                text: `<font color="${Theme.textSecondary}">${modelData[0]}</font> ${modelData[1]}`
                                color: Theme.textDisabled
                                font.family: Theme.monoFont
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }
                }
            }
        }
    }

    component SectionLabel: Text {
        color: Theme.textSecondary
        font.family: Theme.monoFont
        font.pixelSize: Theme.fontSizeSmall
        font.letterSpacing: 0.6
        font.capitalization: Font.AllUppercase
    }
}
