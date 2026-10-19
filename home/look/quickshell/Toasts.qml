// Toasts.qml: on-screen notifications, top-right below the bar, on the focused screen.
// Critical toasts live in their own window on the overlay layer (visible over fullscreen);
// the rest are on the top layer (hidden by Hyprland while a window is fullscreen) and
// stack under the critical ones. Empty space is click-through (mask).
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Scope {
    id: root

    readonly property var targetScreen:
        Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    // Window y so the first card sits 8 px below the 32 px bar (windows have a 12 px
    // margin around the list for the drop shadow).
    readonly property int firstTop: 28

    ToastWindow {
        id: criticalWindow
        model: NotificationService.criticalToasts
        top: root.firstTop
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-toasts-critical"
    }

    ToastWindow {
        model: NotificationService.normalToasts
        top: root.firstTop + (criticalWindow.visible ? criticalWindow.listHeight + 10 : 0)
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-toasts"
    }

    component ToastWindow: PanelWindow {
        id: window

        property ListModel model
        property int top
        readonly property real listHeight: list.contentHeight

        screen: root.targetScreen
        anchors { top: true; right: true }
        margins.top: top
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand // inline replies
        color: "transparent"

        implicitWidth: 360 + 24
        implicitHeight: Math.max(1, heldHeight + 24)

        // Grow at once, but shrink only after the remove / displace animations, so a
        // fading toast is never cut off by the window edge.
        property real heldHeight: 0
        readonly property real targetHeight: list.contentHeight
        onTargetHeightChanged: {
            if (targetHeight >= heldHeight) { shrink.stop(); heldHeight = targetHeight; }
            else shrink.restart();
        }
        Timer { id: shrink; interval: Theme.durationNormal + 40; onTriggered: window.heldHeight = list.contentHeight }

        // Stay mapped briefly after the last toast so its fade-out can play.
        visible: model.count > 0 || linger.running
        Timer { id: linger; interval: Theme.durationFast + 60 }
        Connections {
            target: window.model
            function onCountChanged() { if (window.model.count === 0) linger.restart(); }
        }

        mask: Region { item: list }

        ListView {
            id: list
            x: 12
            y: 12
            width: 360
            height: contentHeight
            interactive: false
            spacing: 10
            model: window.model

            delegate: ToastCard {}

            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: Theme.durationFast }
            }
            displaced: Transition {
                NumberAnimation { property: "y"; duration: Theme.durationNormal; easing.type: Easing.OutCubic }
            }
        }
    }
}
