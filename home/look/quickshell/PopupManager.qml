// PopupManager.qml: which bar popup is open. Only one at a time: opening one closes the
// others (popups call opened(name) when shown, closed(name) when closing, and watch
// `current`). No closing on clicks outside: Hyprland refuses the popups' focus grabs.
// Close with the chip, Escape, or by opening another chip.
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

    function justClosed(name) { return Date.now() - (closedAt[name] ?? 0) < 300; }
}
