// ToolsService.qml: the Tools menu's data and actions. Categories are plain data, so a new
// category or tool is a new entry here plus a case in run(). Screenshots run
// tools/screenshot.sh (next to this file) detached.
// IPC: `quickshell ipc -c bar call tools toggle` / `... tools screenshot region|window`.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: service

    readonly property string screenshotScript: Quickshell.shellDir + "/tools/screenshot.sh"

    // [{ title, icon, items: [{ title, subtitle, icon, action }] }]; icons are Glyphs kinds.
    readonly property var categories: [
        {
            title: "Screenshot",
            icon: "camera",
            items: [
                { title: "Region", subtitle: "select area → clipboard", icon: "region", action: "screenshot:region" },
                { title: "Window", subtitle: "active window → /tmp", icon: "window", action: "screenshot:window" },
            ],
        },
    ]

    // For the chip (IPC toggle).
    signal toggleRequested()

    function run(action) {
        const [kind, arg] = action.split(":");
        if (kind === "screenshot") screenshot(arg);
    }

    // Starts ~200 ms later, so a closing menu has faded out and isn't captured.
    property string pendingMode: ""

    function screenshot(mode) {
        if (mode !== "region" && mode !== "window") return;
        pendingMode = mode;
        captureDelay.restart();
    }

    Timer {
        id: captureDelay
        interval: 200
        onTriggered: Quickshell.execDetached([service.screenshotScript, service.pendingMode])
    }

    IpcHandler {
        target: "tools"
        function toggle(): void { service.toggleRequested(); }
        function screenshot(mode: string): void { service.screenshot(mode); }
    }
}
