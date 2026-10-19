// WindowTitle.qml: focused window's icon + title for the Quickshell bar (Quickshell 0.3.0).
// Place it right after Workspaces; it collapses to zero width when there is nothing to show.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Item {
    id: root

    property int maxTitleWidth: 420

    // ---- Data -------------------------------------------------------------
    // Preferred source: the foreign-toplevel protocol.
    readonly property var toplevel: ToplevelManager.activeToplevel

    // Fallback: Hyprland "activewindow" events ("class,title").
    property string eventClass: ""
    property string eventTitle: ""
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activewindow") return;
            const data = event.data;
            const comma = data.indexOf(",");
            root.eventClass = comma < 0 ? data : data.slice(0, comma);
            root.eventTitle = comma < 0 ? "" : data.slice(comma + 1);
        }
    }

    readonly property string appId: toplevel ? toplevel.appId : eventClass
    readonly property string cleanTitle: stripSuffix(toplevel ? toplevel.title : eventTitle)

    readonly property var workspace: Hyprland.focusedMonitor?.activeWorkspace ?? null
    readonly property int workspaceId: workspace?.id ?? 0
    readonly property bool hasWindows: (workspace?.toplevels.values.length ?? 0) > 0
    readonly property bool shown: hasWindows && cleanTitle !== ""

    readonly property var appSuffixes: [" - Google Chrome", " - Visual Studio Code", " - KeePassXC"]

    function stripSuffix(title) {
        let t = title ?? "";
        for (const suffix of appSuffixes)
            if (t.endsWith(suffix)) return t.slice(0, -suffix.length);
        return t;
    }

    // What is currently drawn; swapped mid-fade so the old title fades out first.
    property string shownTitle: ""
    property string shownAppId: ""
    property int shownWorkspaceId: 0

    readonly property string glyphKind: Glyphs.kindFor(shownAppId)
    // DesktopEntries loads asynchronously on first use, so depend on the list
    // to retry the lookup as entries arrive (reading it also starts the scan).
    readonly property var desktopEntry: {
        if (DesktopEntries.applications.values.length === 0) return null;
        return glyphKind === "" && shownAppId !== ""
            ? DesktopEntries.heuristicLookup(shownAppId) : null;
    }
    readonly property string iconSource: desktopEntry
        ? Quickshell.iconPath(desktopEntry.icon, "application-x-executable") : ""
    readonly property bool hasIcon: glyphKind !== "" || iconSource !== ""

    // ---- Motion -----------------------------------------------------------
    property real slide: 0 // +1: pill moved right, -1: left, 0: same workspace

    function refresh() {
        if (!shown) return; // keep the last title while collapsing
        if (cleanTitle === shownTitle && appId === shownAppId) return;
        if (shownTitle === "") { // first appearance: no cross-fade needed
            swap();
            return;
        }
        slide = Math.sign(workspaceId - shownWorkspaceId);
        crossFade.restart();
    }

    function swap() {
        shownTitle = cleanTitle;
        shownAppId = appId;
        shownWorkspaceId = workspaceId;
    }

    // Let the workspace switch and title update land together before animating.
    onCleanTitleChanged: Qt.callLater(refresh)
    onAppIdChanged: Qt.callLater(refresh)
    onShownChanged: Qt.callLater(refresh)

    SequentialAnimation {
        id: crossFade
        ParallelAnimation {
            NumberAnimation { target: content; property: "opacity"; to: 0; duration: Theme.durationFast / 2; easing.type: Easing.InQuad }
            NumberAnimation { target: content; property: "x"; to: root.slide * 6; duration: Theme.durationFast / 2; easing.type: Easing.InQuad }
        }
        ScriptAction { script: { root.swap(); content.x = -root.slide * 6; } }
        ParallelAnimation {
            NumberAnimation { target: content; property: "opacity"; to: 1; duration: Theme.durationFast / 2; easing.type: Easing.OutQuad }
            NumberAnimation { target: content; property: "x"; to: 0; duration: Theme.durationFast / 2; easing.type: Easing.OutQuad }
        }
    }

    // ---- Layout -----------------------------------------------------------
    clip: true
    implicitHeight: 26
    implicitWidth: shown ? content.implicitWidth : 0
    Behavior on implicitWidth { NumberAnimation { duration: Theme.durationSlow; easing.type: Easing.InOutCubic } }

    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.durationSlow; easing.type: Easing.InOutCubic } }

    Row {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7

        AppGlyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.glyphKind !== ""
            kind: root.glyphKind
            color: Theme.accent
            size: Theme.iconSize
        }

        // Desktop-entry icon, desaturated so it sits with the glyphs.
        Image {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.glyphKind === "" && root.iconSource !== ""
            width: Theme.iconSize
            height: Theme.iconSize
            sourceSize: Qt.size(28, 28)
            source: visible ? root.iconSource : ""
            opacity: 0.7
            layer.enabled: true
            layer.effect: MultiEffect { saturation: -1 }
        }

        Text {
            id: titleText
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(fullWidth.advanceWidth, root.maxTitleWidth)
            text: root.shownTitle
            elide: Text.ElideRight
            color: Theme.textPrimary
            opacity: 0.8
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontSize

            TextMetrics {
                id: fullWidth
                font: titleText.font
                text: titleText.text
            }

            HoverHandler { id: hover }
        }
    }

    // ---- Tooltip ------------------------------------------------------------
    PopupWindow {
        id: tooltip

        anchor.item: titleText
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.margins.top: 8
        implicitWidth: tipText.implicitWidth + 20
        implicitHeight: tipText.implicitHeight + 12
        color: "transparent"
        visible: tipDelay.ready && hover.hovered && root.shown

        Timer {
            id: tipDelay
            property bool ready: false
            interval: 500
            running: hover.hovered
            onTriggered: ready = true
            onRunningChanged: if (!running) ready = false
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSmall
            color: Theme.raised
            border.width: Theme.borderWidth
            border.color: Theme.border
        }

        Text {
            id: tipText
            anchors.centerIn: parent
            text: root.shownTitle
            color: Theme.textPrimary
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontSize
        }
    }
}
