// AgentsChip.qml: hosts Omarchy's vendored agents plugin (home/agent-usage, merged into
// this config's root as plugins/agents + the qs.Commons / qs.Ui modules it imports).
// It plays Omarchy's bar for the plugin: a PluginBarApi with this bar's colours and
// font, and settings = the plugin manifest's defaults overlaid with
// ~/.config/agent-usage/settings.json (written by programs.agent-usage, watched).
// Shown only when the host enables it (Host.agentUsage).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui as Ui

Item {
    id: root

    implicitWidth: chip.implicitWidth
    implicitHeight: chip.implicitHeight

    readonly property url pluginDir: Qt.resolvedUrl("plugins/agents/")
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")

    // ---- Settings: manifest defaults, then the user's file on top ----

    function parse(raw) {
        try {
            const v = JSON.parse(raw || "{}");
            return v && typeof v === "object" && !Array.isArray(v) ? v : {};
        } catch (e) {
            return {};
        }
    }

    function overlay(base, top) {
        const out = Object.assign({}, base);
        for (const k in top) {
            const b = out[k], t = top[k];
            out[k] = b && t && typeof b === "object" && typeof t === "object" && !Array.isArray(t)
                ? overlay(b, t) : t;
        }
        return out;
    }

    readonly property var defaults: (parse(manifestFile.text()).barWidget || {}).defaults || {}
    readonly property var settings: overlay(defaults, parse(settingsFile.text()))

    FileView {
        id: manifestFile
        path: decodeURIComponent(String(root.pluginDir).replace(/^file:\/\//, "")) + "manifest.json"
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: settingsFile
        path: root.configHome + "/agent-usage/settings.json"
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: reload()
    }

    // ---- The bar, as the plugin sees it ----

    Ui.PluginBarApi {
        id: api
        pluginId: "omarchy.agents"
        moduleName: "omarchy.agents"

        foreground: Theme.textPrimary
        barForeground: Theme.accent
        background: Theme.base
        urgent: Theme.error
        fontFamily: Theme.monoFont
        position: "top"
        barSize: Theme.barChipHeight

        _showTooltip: function(target, text) {}
        _hideTooltip: function(target) {}
        _registerClickTarget: function(target) {
            if (api.clickTargets.indexOf(target) < 0) api.clickTargets = api.clickTargets.concat([target]);
        }
        _unregisterClickTarget: function(target) {
            api.clickTargets = api.clickTargets.filter(t => t !== target);
        }
        // One bar popup at a time: the panel joins PopupManager like the other chips.
        _requestPopout: function(owner) {
            api.activePopout = owner;
            PopupManager.opened("agents");
        }
        _releasePopout: function(owner) {
            if (api.activePopout === owner) api.activePopout = null;
            PopupManager.closed("agents");
        }
        _switchPanelFrom: function(owner, direction) { return false; }
        _targetBelongsToWindow: function(target, window) {
            return !!target && !!target.QsWindow && target.QsWindow.window === window;
        }
        _moduleWidgets: function(id) { return []; }
        _run: function(command) { Quickshell.execDetached(["bash", "-lc", command]); }
    }

    // The agents panel (Omarchy's KeyboardPanel) passes a click on the bar only to click
    // targets registered with it. This one covers the whole bar strip, so a click on any
    // other chip while the panel is open reaches that chip (and opens its popup) instead
    // of only closing the panel. Registered first, so the panel's own button wins.
    // triggerPress gets the bar point and event from patch 0007 of the vendored panel.
    Item {
        id: barProxy
        parent: root.QsWindow.window ? root.QsWindow.window.contentItem : root
        anchors.fill: parent
        z: -1

        function triggerPress(button, point, mouse) {
            const win = root.QsWindow.window;
            if (!point || !mouse || !win) return;
            const target = PopupManager.areaAt(win.contentItem, point.x, point.y);
            if (target && (target.acceptedButtons & button)) target.clicked(mouse);
            else PopupManager.dismiss();
        }

        Component.onCompleted: api.registerClickTarget(barProxy)
    }

    // Opening another bar popup closes this one.
    Connections {
        target: PopupManager
        function onCurrentChanged() {
            if (PopupManager.current !== "agents" && plugin.item && plugin.item.opened) plugin.item.close();
        }
    }

    Rectangle {
        id: chip

        implicitWidth: plugin.item ? plugin.item.implicitWidth + Theme.barChipPadding : Theme.barChipHeight
        implicitHeight: Theme.barChipHeight
        radius: Theme.radiusSmall
        color: hover.hovered || PopupManager.hovers(chip) || (plugin.item && plugin.item.opened) ? Theme.chipHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        HoverHandler { id: hover }

        Loader {
            id: plugin
            anchors.centerIn: parent
            width: item ? item.implicitWidth : 0
            height: parent.height
            Component.onCompleted: setSource(root.pluginDir + "Panel.qml", { bar: api })
            onLoaded: item.settings = Qt.binding(() => root.settings)
        }
    }
}
