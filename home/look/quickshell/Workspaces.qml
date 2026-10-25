// Workspaces.qml: Hyprland workspace strip for Quickshell (checked against Quickshell 0.3.0).
// Drop next to your shell.qml and use it as `Workspaces {}`.
import QtQuick
import Quickshell
import Quickshell.Hyprland

Rectangle {
    id: root

    // ---- Tunables ---------------------------------------------------------
    // Icon per workspace number; workspaces not listed show their number.
    property var workspaceIcons: ({ 1: "globe", 2: "code", 5: "lock" })
    // Slots exist for workspaces 1..maxWorkspace and are hidden unless shown.
    property int maxWorkspace: 10
    property int slotHeight: Theme.barItemHeight
    property int iconSize: Theme.iconSize
    property int padding: 3
    property int gap: 4

    // ---- State ------------------------------------------------------------
    readonly property int activeId: Hyprland.focusedMonitor?.activeWorkspace?.id ?? -1

    // Shown workspaces: regular ones with windows, plus the active one even if empty.
    readonly property var shownIds: {
        const ids = [];
        for (const ws of Hyprland.workspaces.values)
            if (ws.id > 0 && (ws.id === activeId || ws.toplevels.values.length > 0))
                ids.push(ws.id);
        if (activeId > 0 && !ids.includes(activeId)) ids.push(activeId);
        return ids.sort((a, b) => a - b);
    }

    // Window addresses flagged by Hyprland "urgent" events, keyed the way
    // HyprlandToplevel.address formats them (lowercase hex, no 0x).
    // Reassigned (never mutated) so bindings that read it re-evaluate.
    property var urgentAddresses: ({})

    property real wheelAccum: 0

    // Follow the springing pill as well, so it never pokes past the glass.
    implicitWidth: Math.max(strip.implicitWidth + padding * 2,
                            pill.visible ? pill.x + pill.width + padding : 0)
    implicitHeight: slotHeight + padding * 2
    radius: Theme.radius
    color: Theme.raised
    border.width: Theme.borderWidth
    border.color: Theme.border

    // ---- Helpers ----------------------------------------------------------
    function workspaceById(id) {
        const list = Hyprland.workspaces.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].id === id) return list[i];
        return null;
    }

    function normalizeAddress(s) {
        return String(s).trim().toLowerCase().replace(/^0x/, "").replace(/^0+/, "");
    }

    function hasUrgent(windows) {
        for (let i = 0; i < windows.length; i++)
            if (urgentAddresses[windows[i].address]) return true;
        return false;
    }

    function clearUrgentFor(id) {
        const ws = workspaceById(id);
        if (!ws) return;
        const next = Object.assign({}, urgentAddresses);
        let changed = false;
        for (const t of ws.toplevels.values) {
            if (next[t.address]) { delete next[t.address]; changed = true; }
        }
        if (changed) urgentAddresses = next;
    }

    function focusWorkspace(id) {
        // Hyprland's Lua config rejects the legacy "workspace N" dispatcher.
        Hyprland.dispatch(Hyprland.usingLua
            ? `hl.dsp.focus({ workspace = ${id} })`
            : `workspace ${id}`);
    }

    // ---- Urgency tracking -------------------------------------------------
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            // Quickshell can miss a workspace that Hyprland creates together with a
            // window (e.g. an app opened straight onto workspace 5), leaving it out of
            // Hyprland.workspaces. Re-sync shortly after any structural change.
            if (root.resyncEvents.includes(event.name)) resync.restart();

            if (event.name !== "urgent") return;
            const addr = root.normalizeAddress(event.data);
            if (!addr.length) return;
            const next = Object.assign({}, root.urgentAddresses);
            next[addr] = true;
            root.urgentAddresses = next;
        }
    }

    readonly property var resyncEvents: [
        "openwindow", "closewindow", "movewindow", "movewindowv2",
        "createworkspace", "createworkspacev2", "destroyworkspace", "destroyworkspacev2",
    ]

    Timer {
        id: resync
        interval: 150
        onTriggered: {
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
        }
    }

    // Also sync once at startup, for windows that opened while the bar was starting.
    Component.onCompleted: resync.restart()

    onActiveIdChanged: {
        clearUrgentFor(activeId);
        // Slot visibility settles in this same pass; measure afterwards.
        Qt.callLater(pill.sync);
    }

    // ---- Active pill (one item, springs between slots) ---------------------
    Rectangle {
        id: pill

        property Item target: null
        property bool settled: false
        property bool syncing: false

        // Place the pill from the laid-out Row, never from a slot that has not
        // been positioned yet (that is what made it flash from the left edge).
        function sync() {
            if (syncing) return;
            syncing = true;
            strip.forceLayout();
            const id = root.activeId;
            const slot = id >= 1 && id <= root.maxWorkspace ? slots.itemAt(id - 1) : null;
            target = slot && slot.visible ? slot : null;
            if (target) {
                x = strip.x + target.x;
                width = target.width;
            }
            syncing = false;
        }

        visible: target !== null
        y: root.padding
        height: root.slotHeight
        radius: Theme.radiusSmall
        color: Theme.accentBg // subtle olive, the active number is lime

        // Skip the spring for the very first placement.
        Component.onCompleted: Qt.callLater(() => { sync(); settled = true; })
        Behavior on x { enabled: pill.settled; SpringAnimation { spring: Theme.springStrength; damping: Theme.springDamping } }
        Behavior on width { enabled: pill.settled; SpringAnimation { spring: Theme.springStrength; damping: Theme.springDamping } }
    }

    // ---- Slots ------------------------------------------------------------
    Row {
        id: strip

        // Fires after slots appear/disappear or change width (e.g. the app name).
        onPositioningComplete: pill.sync()

        x: root.padding
        y: root.padding
        spacing: root.gap

        Repeater {
            id: slots
            // Fixed set of delegates, so slots are never recreated when windows
            // open or close; Row skips the hidden ones.
            model: root.maxWorkspace

            delegate: Item {
                id: slot

                required property int index
                readonly property int wsId: index + 1
                readonly property var ws: root.workspaceById(wsId)
                readonly property var windows: ws ? ws.toplevels.values : []
                readonly property bool occupied: windows.length > 0
                readonly property bool active: wsId === root.activeId
                readonly property bool urgent: !active && root.hasUrgent(windows)
                readonly property string iconKind: root.workspaceIcons[wsId] ?? ""
                readonly property color fg: active ? Theme.accent
                                          : urgent ? Theme.warning
                                          : occupied ? Theme.textSecondary
                                          : Theme.textDisabled

                visible: active || occupied

                width: Math.max(root.slotHeight, content.implicitWidth + 16)
                height: root.slotHeight

                // Hover: same wash as the bar chips (the active slot keeps its lime pill).
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: (slotMouse.containsMouse || PopupManager.hovers(slotMouse)) && !slot.active ? Theme.chipHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                // Urgent: soft pulsing background.
                Rectangle {
                    id: urgentGlow
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: Theme.warning
                    visible: slot.urgent
                    opacity: 0.1

                    SequentialAnimation on opacity {
                        running: slot.urgent
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.28; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.08; duration: 700; easing.type: Easing.InOutSine }
                    }
                }

                Row {
                    id: content
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    spacing: 6

                    AppGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: slot.iconKind !== ""
                        kind: slot.iconKind
                        color: slot.fg
                        size: root.iconSize
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: slot.iconKind === ""
                        text: slot.wsId
                        color: slot.fg
                        font.family: Theme.monoFont
                        font.pixelSize: root.iconSize
                    }
                }

                // 3px dot under occupied, inactive slots.
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    width: 3
                    height: 3
                    radius: 1.5
                    color: slot.fg
                    visible: slot.occupied && !slot.active
                }

                MouseArea {
                    id: slotMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.focusWorkspace(slot.wsId)
                }
            }
        }
    }

    // Scroll anywhere over the strip: up = previous, down = next shown workspace (wraps).
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            root.wheelAccum += event.angleDelta.y;
            if (Math.abs(root.wheelAccum) < 120) return;
            const step = root.wheelAccum > 0 ? -1 : 1;
            root.wheelAccum = 0;
            const ids = root.shownIds;
            if (!ids.length) return;
            const at = ids.indexOf(root.activeId);
            const next = at < 0 ? 0 : (at + step + ids.length) % ids.length;
            root.focusWorkspace(ids[next]);
        }
    }
}
