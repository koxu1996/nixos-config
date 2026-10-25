// BarPopup.qml: base for the bar's popups, after Omarchy's KeyboardPanel. Instead of an
// xdg-popup with a Hyprland focus grab (which Hyprland refused and which handed focus
// back to the hidden drop-down terminal), each popup is a transparent full-screen
// overlay layer on the chip's screen:
// - The card sits under the chip. Its children are laid out in `holder`, a rectangle the
//   size of `cardWidth` x `cardHeight`, placed where the old popup window was (`align`).
// - A click anywhere else on that screen (or on another screen, through a transparent
//   twin there) closes it. The overlay covers the bar too and passes a click (or wheel)
//   there on to the chip's MouseArea underneath, so another chip opens in one click. The
//   bar must never receive the click itself: it takes no keyboard focus, so Hyprland would
//   move focus back to its last window, the hidden drop-down terminal, and pop it up.
// - Keyboard focus follows `open`: a brief Exclusive prime (75 ms) so the card gets keys
//   as soon as it maps, then OnDemand, and None the moment it closes (not after the fade).
// Popups keep their own open/visible/show/close logic and the PopupManager wiring; an
// outside click goes through PopupManager.dismiss(), which closes whichever is open.
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property Item anchorItem
    // Where the card sits relative to the chip: "right" = right edges aligned (grows to
    // the left), "left" = left edges aligned, "center" = centred under the chip.
    property string align: "right"
    property real cardWidth: 300
    property real cardHeight: 200
    // True between show() and close(); popups set it after their fade-in delay.
    property bool open: false
    property bool focusPrimed: false

    default property alias content: holder.data
    readonly property alias holder: holder

    readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
    readonly property real barHeight: anchorWindow ? anchorWindow.height : 0
    readonly property real screenW: screen ? screen.width : 0
    readonly property real screenH: screen ? screen.height : 0
    readonly property int margin: 6

    screen: anchorWindow ? anchorWindow.screen : null
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: false

    WlrLayershell.namespace: "quickshell-popup"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? (focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
                                      : WlrKeyboardFocus.None

    onOpenChanged: {
        focusPrimed = false;
        if (open) focusPrime.restart();
        else focusPrime.stop();
    }

    Timer {
        id: focusPrime
        interval: 75
        onTriggered: if (root.open) root.focusPrimed = true
    }

    // While open the whole screen takes input (the card, the bar strip and the dismiss
    // area); while fading out only the card does, so the dying overlay swallows no clicks.
    mask: Region {
        x: root.open ? 0 : holder.x
        y: root.open ? 0 : holder.y
        width: root.open ? root.screenW : holder.width
        height: root.open ? root.screenH : holder.height
    }

    // The chip's position in the bar, kept current as the bar's layout changes. The bar
    // spans its screen's width from the top-left corner, so bar coordinates are screen
    // coordinates.
    TransformWatcher {
        id: anchorWatcher
        a: root.anchorWindow ? root.anchorWindow.contentItem : null
        b: root.anchorItem
    }

    readonly property point anchorPos: {
        anchorWatcher.transform; // reactive dependency
        if (!anchorItem || !anchorWindow) return Qt.point(0, 0);
        return anchorItem.mapToItem(anchorWindow.contentItem, 0, 0);
    }

    function trackBarHover(px, py) {
        PopupManager.barHover = open && anchorWindow && py >= 0 && py < barHeight
            ? { window: anchorWindow, x: px, y: py } : null;
    }
    onVisibleChanged: if (!visible) trackBarHover(-1, -1)

    // The bar's MouseArea under a point (screen = bar coordinates).
    function barTargetAt(px, py) {
        return anchorWindow ? PopupManager.areaAt(anchorWindow.contentItem, px, py) : null;
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.open
        acceptedButtons: Qt.AllButtons
        // The bar's chips are covered, so tell them where the pointer is (hover highlight).
        hoverEnabled: true
        onPositionChanged: mouse => root.trackBarHover(mouse.x, mouse.y)
        onExited: root.trackBarHover(-1, -1)
        // Close first, then pass a click on the bar on: a workspace button or another chip
        // does its thing and the popup goes too. This popup's own chip then just closes
        // it (justClosed keeps its toggle from reopening it).
        onClicked: mouse => {
            const target = mouse.y < root.barHeight ? root.barTargetAt(mouse.x, mouse.y) : null;
            PopupManager.dismiss();
            if (target && (target.acceptedButtons & mouse.button)) target.clicked(mouse);
        }
        onWheel: wheel => {
            const target = wheel.y < root.barHeight ? root.barTargetAt(wheel.x, wheel.y) : null;
            if (target) target.wheel(wheel);
        }
    }

    Item {
        id: holder

        readonly property real anchorW: root.anchorItem ? root.anchorItem.width : 0
        readonly property real anchorH: root.anchorItem ? root.anchorItem.height : 0
        readonly property real wantedX: root.align === "left" ? root.anchorPos.x
            : root.align === "center" ? root.anchorPos.x + anchorW / 2 - width / 2
            : root.anchorPos.x + anchorW - width

        x: Math.round(Math.max(root.margin, Math.min(wantedX, root.screenW - width - root.margin)))
        y: Math.round(root.anchorPos.y + anchorH + Theme.popupGap)
        width: root.cardWidth
        height: root.cardHeight
        // Controls go dead the moment the popup closes, not after its fade-out.
        enabled: root.open

        // Clicks on the card (outside its controls) stay on the card.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }
    }

    // Pointer input is per output, so other screens get a transparent twin whose only job
    // is to catch a click there. It never takes keyboard focus.
    Variants {
        model: root.open ? Quickshell.screens : []

        delegate: Component {
            PanelWindow {
                required property var modelData

                screen: modelData
                visible: root.open && !!root.screen && modelData.name !== root.screen.name
                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                WlrLayershell.namespace: "quickshell-popup-dismiss"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onPressed: PopupManager.dismiss()
                }
            }
        }
    }
}
