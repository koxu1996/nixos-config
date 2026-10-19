// Quickshell bar for Hyprland (the whole top bar; no waybar under Hyprland).
// Left: system menu (snowflake), workspace selector. Centre: kept free for the notch.
// Right end: now playing, CPU/memory stats, speaker volume, Glow, Wi-Fi + battery (where the host has them, Host.qml), clock, notifications. Toasts: top-right below the bar.
// One set per screen. Started by the quickshell user service (hyprland-session.target).
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

ShellRoot {
    // Notification popups (the notification daemon lives in NotificationService).
    Toasts {}

    // App launcher (Super+D): one window, opened on the focused screen.
    Launcher {}

    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen
            required property var modelData

            // The bar: full width, 32px, reserves its space (exclusive zone) so windows
            // start below it. No background: the widgets sit directly on the wallpaper.
            // With the MacBook notch shown (kernel appledrm.show_notch=1, 1280×832 logical)
            // the bar lives beside the notch: nothing is placed in the centre gap.
            PanelWindow {
                id: bar

                // The notch adds 32 logical px of height (64 physical) above the usual 800.
                readonly property bool hasNotch: perScreen.modelData.name === "eDP-1"
                                                 && perScreen.modelData.height >= 832
                // Width kept free around the screen centre: the notch plus a small margin
                // (my.look.notchGap; 0 on hosts without a notch).
                readonly property int notchGap: hasNotch ? Host.notchGap : 0

                screen: perScreen.modelData
                anchors { top: true; left: true; right: true }
                implicitHeight: 32
                color: "transparent"
                // No keyboard focus, except on demand (a click into it) while the Wi-Fi panel is
                // open, for its password field. Taking focus otherwise made Hyprland hand it back
                // to the hidden dropdown terminal when a popup closed, which pops that terminal up.
                WlrLayershell.keyboardFocus: PopupManager.current === "wifi" ? WlrKeyboardFocus.OnDemand
                                                                             : WlrKeyboardFocus.None

                Item {
                    id: strip
                    anchors.fill: parent

                // ---- Left half: system menu, workspaces ----
                SystemChip {
                    id: systemChip
                    x: 6
                    anchors.verticalCenter: workspaces.verticalCenter
                }

                Workspaces {
                    id: workspaces
                    anchors.left: systemChip.right
                    anchors.leftMargin: 6
                }

                // Fullscreen (hyprland.nix lays fullscreen windows out below the bar): the whole
                // bar row turns black, so it blends with the notch, as on macOS. It also swallows
                // clicks, since the widgets underneath are hidden.
                // Counts the shown special workspace too (the drop-down terminal lives on one),
                // which Hyprland reports only through "activespecial" events.
                readonly property var monitor: Hyprland.monitorFor(perScreen.modelData)
                property string shownSpecial: ""
                readonly property bool fullscreenHere: (monitor?.activeWorkspace?.hasFullscreen ?? false)
                    || (shownSpecial !== ""
                        && (Hyprland.workspaces.values.find(w => w.name === shownSpecial)?.hasFullscreen ?? false))

                Connections {
                    target: Hyprland
                    // "activespecial>>special:dropterm,eDP-1" (empty name when it closes).
                    function onRawEvent(event) {
                        if (event.name !== "activespecial") return;
                        const [name, monitorName] = event.data.split(",");
                        if (monitorName === strip.monitor?.name) strip.shownSpecial = name;
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    z: 100
                    visible: strip.fullscreenHere
                    color: Theme.notchFill

                    MouseArea { anchors.fill: parent }
                }

                // ---- Right half ----
                Row {
                    id: rightEnd
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Media { compact: true } // cover + equaliser
                    SystemStats {}
                    Volume {}
                    GlowButton {}
                    // Wi-Fi and battery only where the host has them (my.look.*).
                    Loader { active: Host.wifi; sourceComponent: Wifi {} }
                    Loader { active: Host.battery; sourceComponent: Battery {} }
                    ToolsChip {}
                    ClockChip {}
                    NotificationChip {}
                }
                }
            }
        }
    }
}
