// PopupManager.qml: which bar popup is open. Only one at a time: opening one closes the
// others (popups call opened(name) when shown, closed(name) when closing, and watch
// `current`). A click outside the open popup (BarPopup's overlay) calls dismiss(), which
// closes it the same way. Also closed by its chip, Escape, or opening another chip.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    property string current: ""
    property var closedAt: ({})

    function opened(name) { current = name; }

    function closed(name) {
        closedAt[name] = Date.now();
        if (current === name) current = "";
    }

    // Close whichever popup is open (each one closes itself when `current` moves off it).
    function dismiss() { current = ""; }

    function justClosed(name) { return Date.now() - (closedAt[name] ?? 0) < 300; }

    // The MouseArea under a point of `item` (in its coordinates) that would get a click
    // there, for overlays that pass a click on the bar on to the chip underneath. Like
    // Qt's own dispatch, children under the point are tried topmost first, and a subtree
    // without one passes the click on to the siblings below it (an icon drawn over its
    // button's MouseArea, as in the agents chip, must not hide it).
    function areaAt(item, x, y) {
        if (!item || !item.visible || !item.enabled) return null;
        const kids = Array.from(item.children).map((c, i) => ({ c: c, i: i }))
            .sort((a, b) => (b.c.z - a.c.z) || (b.i - a.i));
        for (const k of kids) {
            const p = item.mapToItem(k.c, x, y);
            if (p.x < 0 || p.y < 0 || p.x >= k.c.width || p.y >= k.c.height) continue;
            const found = areaAt(k.c, p.x, p.y);
            if (found) return found;
        }
        return "pressAndHoldInterval" in item ? item : null; // a MouseArea
    }
}
