// ClaudeDock.qml: the bump on one screen's right edge. A full-height transparent overlay
// (fixed size, so nothing resizes the surface while the bump animates); the input mask
// covers only the bump, so clicks elsewhere reach the windows below.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: dock

    required property var store
    required property ListModel model

    // ---- Look -------------------------------------------------------------------------
    property color fill: "#000000"
    readonly property color amber: "#EF9F27"
    readonly property int bandWidth: 24     // collapsed bump (at least 2 * r: the corner plus the fillet)
    readonly property int flyoutWidth: 300  // bump with the flyout open
    readonly property int r: 12             // left corners and the edge fillets
    readonly property int pad: 16           // above the first dot, below the last
    readonly property int dot: 10
    readonly property int gap: 16           // between dots; each dot's hover/click area spans it
    readonly property int labelHeight: 7    // machine name above each cluster ("AIR"), px
    readonly property int labelGap: 8       // name to its first dot
    readonly property int clusterGap: 6     // added between clusters, on top of the dot gap

    anchors { top: true; bottom: true; right: true }
    implicitWidth: flyoutWidth
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "claude-dock"
    // Focus only while a reply is possible: on click (hover), or at once (hotkey).
    WlrLayershell.keyboardFocus: !(canReply || isNew) ? WlrKeyboardFocus.None
        : openMode === "hotkey" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    mask: Region { item: hit }

    // ---- Flyout state -----------------------------------------------------------------
    property string openId: ""
    property string openMode: ""  // "hover" | "hotkey"
    readonly property var openAgent: {
        store.revision;
        const i = store.indexOf(openId);
        return i < 0 ? null : model.get(i);
    }
    property string hoverId: ""   // dot under the pointer (opens after 150 ms)

    // A reply goes in as a prompt: not while it asks an approval or question (blocked),
    // which Herdr won't type into; that one is answered in the terminal.
    readonly property bool canReply: !!openAgent && openAgent.status === "yours" && openAgent.herdrStatus !== "blocked"

    // The "+" flyout: a new Claude session on the chosen machine, in the chosen folder.
    readonly property string newId: "+"
    readonly property bool isNew: openId === newId
    property int newMachine: 0

    function openFor(id, mode) {
        if (!flyoutOpen) frozen = liveLayout;
        store.now = Date.now();
        if (openId !== id && id !== newId) store.readLast(id);
        if (id === newId && openId !== id) {
            const online = store.machineInfo.filter(m => m.online);
            newMachine = online.length ? online[0].i : 0;
            folderField.text = "~";
        }
        openId = id;
        openMode = mode;
        closeTimer.stop();
        field.text = "";
        if (mode === "hotkey") Qt.callLater(() => field.forceActiveFocus());
    }

    // Up/Down in the "+" flyout: the next reachable machine.
    function stepMachine(step) {
        const online = store.machineInfo.filter(m => m.online);
        if (!online.length) return;
        const at = online.findIndex(m => m.i === newMachine);
        newMachine = online[(at + step + online.length) % online.length].i;
    }
    function startNew(machine) {
        if (!store.machineInfo[machine]?.online) return;
        store.startSession(machine, folderField.text);
        close();
    }
    function close() {
        frozen = null;
        openId = "";
        openMode = "";
        field.focus = false;
        folderField.focus = false;
    }

    Timer { id: hoverTimer; interval: 150; onTriggered: if (dock.hoverId) dock.openFor(dock.hoverId, "hover") }
    Timer { id: closeTimer; interval: 300; onTriggered: if (!field.activeFocus && !folderField.activeFocus) dock.close() }
    // Wait times, only while they can be read.
    // Wait times and the screen read, only while they can be seen (every 5 s for a working
    // agent, whose activity changes).
    Timer {
        interval: dock.openAgent?.herdrStatus === "working" ? 5000 : 15000
        repeat: true
        running: dock.openId !== ""
        onTriggered: {
            dock.store.now = Date.now();
            if (dock.openAgent) dock.store.readLast(dock.openId);
        }
    }

    Connections {
        target: dock.store
        function onHotkey(key, screenName) {
            if (screenName === dock.screen?.name) dock.openFor(key, "hotkey");
            else if (dock.openMode === "hotkey") dock.close();
        }
    }

    // ---- Layout -----------------------------------------------------------------------
    // Clusters per host (in order of first appearance); amber first, longest waiting first.
    // Held while the flyout is open, so no dot slides away from under the pointer; the new
    // order applies when it closes.
    property var frozen: null
    readonly property var layout: flyoutOpen && frozen ? frozen : liveLayout
    readonly property var liveLayout: {
        store.revision;
        const hosts = [];
        const byHost = {};
        for (let i = 0; i < model.count; i++) {
            const a = model.get(i);
            if (!byHost[a.host]) { byHost[a.host] = []; hosts.push(a.host); }
            byHost[a.host].push({ key: a.key, status: a.status, since: a.since, i: i });
        }
        const pos = {};
        const labels = [];
        let y = 0;
        hosts.forEach((h, n) => {
            if (n > 0) y += dock.clusterGap;
            labels.push({ host: h, y: y });
            y += dock.labelHeight + dock.labelGap;
            byHost[h].sort((a, b) => (a.status === "yours") !== (b.status === "yours")
                ? (a.status === "yours" ? -1 : 1)
                : a.status === "yours" ? a.since - b.since : a.i - b.i);
            for (const a of byHost[h]) { pos[a.key] = y; y += dock.dot + dock.gap; }
        });
        // Last slot: the "+" (new session), below the dots.
        return { pos: pos, labels: labels, plus: y, height: y + dock.dot };
    }

    // ---- Bump geometry ----------------------------------------------------------------
    readonly property bool flyoutOpen: openId !== ""
    property real bumpWidth: flyoutOpen ? flyoutWidth : bandWidth
    Behavior on bumpWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    // Body (between the fillets): the dots, or the flyout if it is taller.
    property real bodyHeight: Math.max(layout.height, !flyoutOpen ? 0 : isNew ? newFlyout.implicitHeight : flyout.implicitHeight) + pad * 2
    Behavior on bodyHeight { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    readonly property real bodyTop: Math.round((height - bodyHeight) / 2)
    readonly property real dotsTop: bodyTop + pad + (bodyHeight - pad * 2 - layout.height) / 2
    readonly property real dotX: width - bandWidth / 2 - dot / 2

    // Input region: the bump with its fillets.
    Item {
        id: hit
        x: dock.width - dock.bumpWidth
        y: dock.bodyTop - dock.r
        width: dock.bumpWidth
        height: dock.bodyHeight + dock.r * 2

        HoverHandler {
            id: hitHover
            onHoveredChanged: {
                if (hovered) closeTimer.stop();
                else if (dock.flyoutOpen) closeTimer.restart();
            }
        }
    }

    // One filled path: flat on the right, rounded on the left, flared into the screen edge.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            id: p
            readonly property real w: dock.width
            readonly property real l: dock.width - dock.bumpWidth
            readonly property real t: dock.bodyTop
            readonly property real b: dock.bodyTop + dock.bodyHeight
            readonly property real r: dock.r

            fillColor: dock.fill
            strokeWidth: -1
            startX: p.w; startY: p.t - p.r
            PathArc { x: p.w - p.r; y: p.t; radiusX: p.r; radiusY: p.r; direction: PathArc.Clockwise }
            PathLine { x: p.l + p.r; y: p.t }
            PathArc { x: p.l; y: p.t + p.r; radiusX: p.r; radiusY: p.r; direction: PathArc.Counterclockwise }
            PathLine { x: p.l; y: p.b - p.r }
            PathArc { x: p.l + p.r; y: p.b; radiusX: p.r; radiusY: p.r; direction: PathArc.Counterclockwise }
            PathLine { x: p.w - p.r; y: p.b }
            PathArc { x: p.w; y: p.b + p.r; radiusX: p.r; radiusY: p.r; direction: PathArc.Clockwise }
            PathLine { x: p.w; y: p.t - p.r }
        }
    }

    // ---- Machine names, above each cluster ---------------------------------------------
    Repeater {
        model: dock.layout.labels
        Text {
            required property var modelData
            x: Math.round(dock.width - dock.bandWidth / 2 - implicitWidth / 2)
            y: dock.dotsTop + modelData.y
            text: modelData.host
            color: Qt.rgba(1, 1, 1, 0.4)
            font.family: "JetBrains Mono"
            font.pixelSize: dock.labelHeight
            font.letterSpacing: 0.2
            opacity: dock.flyoutOpen ? 0.4 : 1
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }
    }

    // ---- Dots -------------------------------------------------------------------------
    Repeater {
        model: dock.model

        Item {
            id: dotItem
            required property string key
            required property string status
            readonly property bool yours: status === "yours"
            property bool placed: false

            x: dock.dotX
            y: dock.dotsTop + (dock.layout.pos[key] ?? 0)
            width: dock.dot
            height: dock.dot
            opacity: dock.flyoutOpen && dock.openId !== key ? 0.4 : 1
            Behavior on y { enabled: dotItem.placed; NumberAnimation { duration: 200; easing.type: Easing.InOutCubic } }
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Component.onCompleted: Qt.callLater(() => placed = true)

            onYoursChanged: if (yours && placed) pulse.restart()

            // Working: a ring; idle (seen, nothing asked): a fainter one.
            required property string herdrStatus
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 1.5
                border.color: Qt.rgba(1, 1, 1, dotItem.status === "idle" ? 0.2 : 0.45)
                Behavior on border.color { ColorAnimation { duration: 150 } }
            }
            // Your turn: solid amber, faded in and out.
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: dock.amber
                opacity: dotItem.yours ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
            // Once, on turning amber: a ring grows 10 → 22 px and fades.
            Rectangle {
                id: ring
                anchors.centerIn: parent
                width: dock.dot
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1.5
                border.color: dock.amber
                opacity: 0
            }
            ParallelAnimation {
                id: pulse
                NumberAnimation { target: ring; property: "width"; from: dock.dot; to: 22; duration: 450; easing.type: Easing.OutCubic }
                NumberAnimation { target: ring; property: "opacity"; from: 0.9; to: 0; duration: 450; easing.type: Easing.OutCubic }
            }

            // The whole band's width and the gap around the dot react.
            MouseArea {
                x: -(dock.bandWidth - dock.dot) / 2
                y: -dock.gap / 2
                width: dock.bandWidth
                height: dock.dot + dock.gap
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: { dock.hoverId = dotItem.key; hoverTimer.restart(); }
                onExited: if (dock.hoverId === dotItem.key) { dock.hoverId = ""; hoverTimer.stop(); }
                onClicked: { dock.close(); dock.store.fly(dotItem.key); }
            }
        }
    }

    // ---- New session: "+" ---------------------------------------------------------------
    Item {
        id: plus
        x: dock.dotX
        y: dock.dotsTop + dock.layout.plus
        opacity: dock.flyoutOpen && !dock.isNew ? 0.4 : 1
        Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.InOutCubic } }
        Behavior on opacity { NumberAnimation { duration: 160 } }
        width: dock.dot
        height: dock.dot
        readonly property color ink: plusMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(1, 1, 1, 0.45)

        // 8 px, 1 px lines, no rounding: whole device pixels at scale 2, so it stays sharp.
        Rectangle { x: 1; y: 4.5; width: 8; height: 1; color: plus.ink }
        Rectangle { x: 4.5; y: 1; width: 1; height: 8; color: plus.ink }

        MouseArea {
            id: plusMouse
            x: -(dock.bandWidth - dock.dot) / 2
            y: -dock.gap / 2
            width: dock.bandWidth
            height: dock.dot + dock.gap
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: { dock.hoverId = dock.newId; hoverTimer.restart(); }
            onExited: if (dock.hoverId === dock.newId) { dock.hoverId = ""; hoverTimer.stop(); }
            onClicked: { dock.openFor(dock.newId, "hover"); folderField.forceActiveFocus(); }
        }
    }

    // ---- Flyout -----------------------------------------------------------------------
    // Left of the dots, its first line on the open dot's row; fades in as the bump widens.
    Item {
        x: dock.width - dock.bumpWidth
        y: dock.bodyTop
        width: dock.bumpWidth - dock.bandWidth
        height: dock.bodyHeight
        clip: true
        opacity: Math.max(0, (dock.bumpWidth - dock.bandWidth) / (dock.flyoutWidth - dock.bandWidth) * 1.6 - 0.6)
        visible: opacity > 0

        Column {
            id: flyout
            readonly property var a: dock.openAgent
            readonly property real rowY: dock.dotsTop - dock.bodyTop + (dock.layout.pos[dock.openId] ?? 0) + dock.dot / 2 - 9

            visible: !dock.isNew
            x: dock.pad
            width: dock.flyoutWidth - dock.bandWidth - dock.pad - 4
            y: Math.max(dock.pad, Math.min(rowY, dock.bodyHeight - dock.pad - implicitHeight))
            spacing: 6

            // The session's topic (Claude's terminal title); status and time on the right.
            Item {
                width: parent.width
                height: 18
                Text {
                    anchors.left: parent.left
                    anchors.right: meta.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: flyout.a ? (flyout.a.title && flyout.a.title !== flyout.a.kind ? flyout.a.title : flyout.a.name) : ""
                    elide: Text.ElideRight
                    color: "#ffffff"
                    font.family: "Inter"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
                Text {
                    id: meta
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: flyout.a ? `${dock.statusWord(flyout.a.herdrStatus)} · ${dock.ago(flyout.a.since)}` : ""
                    color: flyout.a?.status === "yours" ? dock.amber : Qt.rgba(1, 1, 1, 0.45)
                    font.family: "JetBrains Mono"
                    font.pixelSize: 10
                }
            }

            // Folder (and the agent, unless it is Claude); the running turn on the right.
            Item {
                width: parent.width
                height: 14
                Text {
                    anchors.left: parent.left
                    anchors.right: turnText.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: flyout.a ? [flyout.a.folder, flyout.a.kind !== "claude" ? flyout.a.kind : ""].filter(s => s).join(" · ") : ""
                    elide: Text.ElideMiddle
                    color: Qt.rgba(1, 1, 1, 0.45)
                    font.family: "JetBrains Mono"
                    font.pixelSize: 10
                }
                Text {
                    id: turnText
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: flyout.a?.herdrStatus === "working"
                    text: visible ? flyout.a?.turn ?? "" : ""
                    color: Qt.rgba(1, 1, 1, 0.35)
                    font.family: "JetBrains Mono"
                    font.pixelSize: 10
                }
            }

            // Working: what it is doing now. Done: its last message. Blocked: that it asks.
            Text {
                width: parent.width
                visible: text !== ""
                text: flyout.a?.herdrStatus === "blocked" ? "Asks for approval or an answer. Click the dot to open it."
                    : flyout.a?.lastLine ?? ""
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                color: Qt.rgba(1, 1, 1, 0.7)
                font.family: "Inter"
                font.pixelSize: 12
                lineHeight: 1.15
            }

            // Reply, only when it waits for you.
            Rectangle {
                width: parent.width
                height: 28
                visible: dock.canReply
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                border.color: field.activeFocus ? Qt.rgba(0.937, 0.624, 0.153, 0.6) : Qt.rgba(1, 1, 1, 0.12)

                TextInput {
                    id: field
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: "#ffffff"
                    selectionColor: Qt.rgba(0.937, 0.624, 0.153, 0.4)
                    font.family: "Inter"
                    font.pixelSize: 12
                    Keys.onReturnPressed: dock.send()
                    Keys.onEnterPressed: dock.send()
                    Keys.onEscapePressed: dock.close()
                    onActiveFocusChanged: if (!activeFocus && !hitHover.hovered) closeTimer.restart()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !field.text && !field.preeditText
                        text: "Reply…"
                        color: Qt.rgba(1, 1, 1, 0.35)
                        font: field.font
                    }
                }
            }
        }

        // "+": machine rows (reachable ones), the folder, recent folders there.
        Column {
            id: newFlyout
            readonly property real rowY: dock.dotsTop - dock.bodyTop + dock.layout.plus + dock.dot / 2 - 9
            readonly property var folders: dock.store.recentFolders(dock.newMachine)

            visible: dock.isNew
            x: dock.pad
            width: flyout.width
            y: Math.max(dock.pad, Math.min(rowY - implicitHeight + 18, dock.bodyHeight - dock.pad - implicitHeight))
            spacing: 6

            Text {
                height: 18
                verticalAlignment: Text.AlignVCenter
                text: "New Claude session"
                color: "#ffffff"
                font.family: "Inter"
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            Repeater {
                model: dock.store.machineInfo
                Rectangle {
                    id: machineRow
                    required property var modelData
                    readonly property bool chosen: dock.newMachine === modelData.i
                    width: newFlyout.width
                    height: 26
                    radius: 7
                    color: chosen ? Qt.rgba(1, 1, 1, 0.1) : rowMouse.containsMouse && modelData.online ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                    opacity: modelData.online ? 1 : 0.4

                    Text {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: machineRow.modelData.label
                        color: "#ffffff"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 11
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: !machineRow.modelData.online ? "offline" : machineRow.modelData.i === 0 ? "this machine" : ""
                        color: Qt.rgba(1, 1, 1, 0.45)
                        font.family: "Inter"
                        font.pixelSize: 11
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: machineRow.modelData.online
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { dock.newMachine = machineRow.modelData.i; dock.startNew(dock.newMachine); }
                    }
                }
            }

            // Folder on that machine; "~" is its home.
            Rectangle {
                width: newFlyout.width
                height: 28
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                border.color: folderField.activeFocus ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.12)

                TextInput {
                    id: folderField
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: "#ffffff"
                    selectionColor: Qt.rgba(1, 1, 1, 0.25)
                    font.family: "JetBrains Mono"
                    font.pixelSize: 11
                    Keys.onReturnPressed: dock.startNew(dock.newMachine)
                    Keys.onEnterPressed: dock.startNew(dock.newMachine)
                    Keys.onUpPressed: dock.stepMachine(-1)
                    Keys.onDownPressed: dock.stepMachine(1)
                    Keys.onEscapePressed: dock.close()
                    onActiveFocusChanged: if (!activeFocus && !hitHover.hovered) closeTimer.restart()
                }
            }

            // Recent folders of agents on that machine.
            Flow {
                width: newFlyout.width
                spacing: 6
                visible: newFlyout.folders.length > 0
                Repeater {
                    model: newFlyout.folders
                    Text {
                        required property string modelData
                        text: modelData
                        color: folderMouse.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.5)
                        font.family: "JetBrains Mono"
                        font.pixelSize: 10
                        MouseArea {
                            id: folderMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { folderField.text = parent.modelData; folderField.forceActiveFocus(); }
                        }
                    }
                }
            }
        }
    }

    // Esc anywhere in the flyout (focus outside the field).
    // (The "+" flyout is inside the clipped flyout item, see newFlyout.)
    Shortcut { sequence: "Escape"; enabled: dock.flyoutOpen; onActivated: dock.close() }

    function send() {
        store.reply(openId, field.text);
        close();
    }

    function statusWord(herdrStatus) {
        return ({ working: "working", blocked: "asks", done: "done", idle: "idle" })[herdrStatus] ?? "…";
    }

    function ago(since) {
        const s = Math.max(0, (store.now - since) / 1000);
        if (s < 60) return "<1 min";
        if (s < 3600) return `${Math.floor(s / 60)} min`;
        return `${Math.floor(s / 3600)} h`;
    }
}
