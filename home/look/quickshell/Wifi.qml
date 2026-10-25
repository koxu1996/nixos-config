// Wifi.qml: Wi-Fi chip (icon only) and popover; state and actions in WifiService.qml.
// Popover: radio switch, current network (signal, tags, traffic, details), nearby networks
// with inline connect / join / forget, and a Tailscale switch.
// Checked against Quickshell 0.3.0. Use it as `Wifi {}` in the bar's right-end Row.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    readonly property var svc: WifiService

    // Popover-local UI state.
    property string expandedSsid: ""
    property string confirmForget: ""
    property bool detailsOpen: false

    implicitWidth: chip.implicitWidth
    implicitHeight: chip.implicitHeight

    function qualityColor(q) {
        return q === "excellent" || q === "good" ? Theme.accent : q === "fair" ? Theme.warning : Theme.error;
    }

    // ---- Chip --------------------------------------------------------------
    Rectangle {
        id: chip

        implicitWidth: Theme.barIconSize + Theme.barChipPadding * 2
        implicitHeight: Theme.barChipHeight
        radius: Theme.radiusSmall
        color: chipHover.hovered || panel.open ? Theme.chipHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        WifiGlyph {
            anchors.centerIn: parent
            size: Theme.barIconSize - 1 // the sun glyph only fills ~20 of its 24px box
            level: root.svc.connected ? root.svc.level : 4
            busy: root.svc.connecting
            off: !root.svc.radioOn
            color: root.svc.connected || root.svc.connecting ? Theme.accent : Theme.textDisabled
        }

        HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
        // A MouseArea (not a TapHandler) so an open popup's overlay can pass a click on to it.
        MouseArea { anchors.fill: parent; onClicked: panel.toggle() }
    }

    // ---- Tooltip ------------------------------------------------------------
    PopupWindow {
        anchor.item: chip
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.bottom: -Theme.popupGap // margins resize the anchor rect; negative = below it
        implicitWidth: tipText.implicitWidth + 20
        implicitHeight: tipText.implicitHeight + 12
        color: "transparent"
        visible: tipDelay.ready && chipHover.hovered && !panel.open

        Timer {
            id: tipDelay
            property bool ready: false
            interval: 500
            running: chipHover.hovered
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
            text: !root.svc.radioOn ? "Wi-Fi off"
                : root.svc.connected ? `${root.svc.ssid} · ${root.svc.rssi} dBm`
                : root.svc.connecting ? `Connecting to ${root.svc.connectingSsid}…`
                : "Not connected"
            color: Theme.textPrimary
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontSize
        }
    }

    // ---- Popover -----------------------------------------------------------
    BarPopup {
        id: panel
        anchorItem: chip
        align: "right"

        function toggle() { if (open) close(); else if (!PopupManager.justClosed("wifi")) show(); }
        function show() {
            PopupManager.opened("wifi");
            visible = true;
            WifiService.panelOpen = true;
            fadeInDelay.restart();
        }
        function close() {
            fadeInDelay.stop();
            open = false;
            WifiService.panelOpen = false;
            PopupManager.closed("wifi");
            hideAfterFade.restart();
        }

        Connections {
            target: PopupManager
            function onCurrentChanged() { if (panel.visible && PopupManager.current !== "wifi") panel.close(); }
        }

        readonly property real maxHeight: (root.QsWindow.window?.screen?.height ?? 800) - 32 - 8 - 12

        cardWidth: 360
        cardHeight: Math.min(content.implicitHeight + Theme.popupPadding * 2, maxHeight)
        color: "transparent"
        visible: false

        // Map the window with the card still transparent and start the fade-in a frame
        // later, so the window's very first frame shows nothing (no stale-frame flash).
        Timer { id: fadeInDelay; interval: 16; onTriggered: { panel.open = true; card.forceActiveFocus(); } }

        Timer {
            id: hideAfterFade
            interval: Theme.durationNormal
            onTriggered: {
                if (panel.open) return;
                panel.visible = false;
                root.expandedSsid = "";
                root.confirmForget = "";
            }
        }

        Rectangle {
            id: card

            width: parent.width
            height: parent.height
            radius: Theme.radiusLarge
            color: Theme.raised
            border.width: Theme.borderWidth
            border.color: Theme.border

            focus: true
            Keys.onEscapePressed: panel.close()

            transformOrigin: Item.TopRight
            opacity: panel.open ? 1 : 0
            scale: panel.open ? 1 : 0.94
            Behavior on opacity { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }

            Flickable {
                anchors.fill: parent
                anchors.margins: Theme.popupPadding
                contentWidth: width
                contentHeight: content.implicitHeight
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Column {
                    id: content
                    width: parent.width
                    spacing: Theme.popupSpacing

                    // ---- 1. Header ----
                    Item {
                        width: parent.width
                        implicitHeight: headerText.implicitHeight

                        Column {
                            id: headerText
                            spacing: 2

                            Text {
                                text: "Wi-Fi"
                                color: Theme.textPrimary
                                font.family: Theme.sansFont
                                font.pixelSize: Theme.fontSizeLarge
                            }

                            Text {
                                text: [root.svc.iface, root.svc.model].filter(x => x).join(" · ")
                                color: Theme.textDisabled
                                font.family: Theme.monoFont
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }

                        Toggle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            checked: root.svc.radioOn
                            enabled: !root.svc.hardBlocked
                            onToggled: root.svc.setRadio(!root.svc.radioOn)
                        }
                    }

                    Text {
                        visible: root.svc.hardBlocked
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: "Blocked by a hardware switch; it can't be turned on from here."
                        color: Theme.warning
                        font.family: Theme.sansFont
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    // ---- 2. Radio off ----
                    Column {
                        visible: !root.svc.radioOn
                        width: parent.width
                        topPadding: 10
                        bottomPadding: 10
                        spacing: 8

                        WifiGlyph {
                            anchors.horizontalCenter: parent.horizontalCenter
                            size: 40
                            off: true
                            color: Theme.textDisabled
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            topPadding: 4
                            text: "Wi-Fi is off"
                            color: Theme.textPrimary
                            font.family: Theme.sansFont
                            font.pixelSize: Theme.fontSizeTitle
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            text: "Turn it on and iwd reconnects to a saved network."
                            color: Theme.textDisabled
                            font.family: Theme.sansFont
                            font.pixelSize: Theme.fontSize
                        }
                    }

                    // ---- 3. Current network ----
                    Rectangle {
                        id: current

                        readonly property string mode: root.svc.connecting ? "connecting"
                                                     : root.svc.connected ? "connected" : "disconnected"

                        visible: root.svc.radioOn
                        width: parent.width
                        implicitHeight: currentContent.implicitHeight + 24
                        radius: Theme.radius
                        color: mode === "connected" ? Theme.alpha(Theme.accent, 0.05) : Theme.inset
                        border.width: Theme.borderWidth
                        border.color: mode === "connected" ? Theme.alpha(Theme.accent, 0.14) : Theme.borderSubtle

                        Column {
                            id: currentContent
                            x: 12
                            y: 12
                            width: parent.width - 24
                            spacing: 12

                            // Title row (connected and connecting).
                            Item {
                                visible: current.mode !== "disconnected"
                                width: parent.width
                                implicitHeight: 34

                                Rectangle {
                                    id: tile
                                    width: 34
                                    height: 34
                                    radius: Theme.radiusSmall
                                    color: current.mode === "connected" ? Theme.accentBg : Theme.alpha(Theme.warning, 0.12)

                                    WifiGlyph {
                                        anchors.centerIn: parent
                                        level: current.mode === "connected" ? root.svc.level : 4
                                        busy: current.mode === "connecting"
                                        color: current.mode === "connected" ? Theme.accent : Theme.warning
                                    }
                                }

                                Column {
                                    anchors.left: tile.right
                                    anchors.leftMargin: 10
                                    anchors.right: signalCol.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: current.mode === "connected" ? root.svc.ssid : root.svc.connectingSsid
                                        color: Theme.textPrimary
                                        font.family: Theme.sansFont
                                        font.pixelSize: Theme.fontSizeLarge
                                        font.weight: Font.Medium
                                    }

                                    Text {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: current.mode === "connected"
                                            ? (root.svc.profile ? "iwd · saved network" : "iwd · not saved")
                                            : "Connecting…"
                                        color: current.mode === "connected" ? Theme.textDisabled : Theme.warning
                                        font.family: current.mode === "connected" ? Theme.monoFont : Theme.sansFont
                                        font.pixelSize: Theme.fontSizeSmall
                                    }
                                }

                                Column {
                                    id: signalCol
                                    visible: current.mode === "connected"
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        anchors.right: parent.right
                                        text: `${root.svc.rssi} dBm`
                                        color: Theme.textPrimary
                                        font.family: Theme.monoFont
                                        font.pixelSize: Theme.fontSize
                                        font.features: { "tnum": 1 }
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        text: root.svc.quality
                                        color: root.qualityColor(root.svc.quality)
                                        font.family: Theme.sansFont
                                        font.pixelSize: Theme.fontSizeSmall
                                    }
                                }
                            }

                            // Connecting: three steps.
                            Row {
                                visible: current.mode === "connecting"
                                width: parent.width

                                Repeater {
                                    model: ["Associating", "Checking password", "Getting address"]

                                    delegate: Row {
                                        id: step
                                        required property int index
                                        required property string modelData
                                        readonly property bool done: index < root.svc.connectStep
                                        readonly property bool active: index === root.svc.connectStep

                                        width: parent.width / 3
                                        spacing: 6

                                        Rectangle {
                                            id: stepDot
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 7
                                            height: 7
                                            radius: 3.5
                                            color: step.done ? Theme.accent : step.active ? Theme.warning : Theme.textFaint

                                            SequentialAnimation on opacity {
                                                running: step.active
                                                loops: Animation.Infinite
                                                NumberAnimation { to: 0.35; duration: 500; easing.type: Easing.InOutSine }
                                                NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
                                                onRunningChanged: if (!running) stepDot.opacity = 1
                                            }
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: step.modelData
                                            color: step.done || step.active ? Theme.textSecondary : Theme.textDisabled
                                            font.family: Theme.sansFont
                                            font.pixelSize: Theme.fontSizeSmall
                                        }
                                    }
                                }
                            }

                            // Connected: tags.
                            Flow {
                                visible: current.mode === "connected"
                                width: parent.width
                                spacing: 6

                                Repeater {
                                    model: current.mode !== "connected" ? [] : [
                                        root.svc.freq ? `${(root.svc.freq / 1000).toFixed(1)} GHz · ch ${root.svc.channel}`
                                            + (root.svc.width ? ` · ${root.svc.width}` : "") : "",
                                        root.svc.wifiGeneration ? `Wi-Fi ${root.svc.wifiGeneration}` : "",
                                        root.svc.security,
                                        root.svc.linkSpeed ? `${root.svc.linkSpeed} Mb/s link` : "",
                                    ].filter(t => t)

                                    delegate: Pill { required property string modelData; text: modelData }
                                }
                            }

                            // Connected: traffic.
                            Row {
                                visible: current.mode === "connected"
                                width: parent.width
                                spacing: 10

                                Rate {
                                    width: (parent.width - parent.spacing) / 2
                                    label: "Down"
                                    rate: root.svc.rxRate
                                    values: root.svc.rxHistory
                                    lineColor: Theme.accent
                                }

                                Rate {
                                    width: (parent.width - parent.spacing) / 2
                                    label: "Up"
                                    rate: root.svc.txRate
                                    values: root.svc.txHistory
                                    lineColor: Theme.textSecondary
                                }
                            }

                            // Connected: details.
                            Column {
                                visible: current.mode === "connected"
                                width: parent.width
                                spacing: 8

                                Row {
                                    spacing: 4

                                    AppGlyph {
                                        anchors.verticalCenter: parent.verticalCenter
                                        kind: "chevronRight"
                                        size: 12
                                        color: Theme.textSecondary
                                        rotation: root.detailsOpen ? 90 : 0
                                        Behavior on rotation { NumberAnimation { duration: Theme.durationFast } }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Details"
                                        color: Theme.textSecondary
                                        font.family: Theme.sansFont
                                        font.pixelSize: Theme.fontSize
                                    }

                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: root.detailsOpen = !root.detailsOpen }
                                }

                                Column {
                                    visible: root.detailsOpen
                                    width: parent.width
                                    spacing: 4

                                    Repeater {
                                        model: [
                                            ["IPv4", root.svc.ipv4],
                                            ["IPv6", root.svc.ipv6],
                                            ["Gateway", root.svc.gateway],
                                            ["DNS", root.svc.dns],
                                            ["BSSID", root.svc.bssid],
                                            ["Online", root.svc.onlineState],
                                        ]

                                        delegate: Row {
                                            required property var modelData
                                            width: parent.width
                                            spacing: 8

                                            Text {
                                                width: 64
                                                text: modelData[0]
                                                color: Theme.textDisabled
                                                font.family: Theme.monoFont
                                                font.pixelSize: Theme.fontSizeSmall
                                            }

                                            Text {
                                                width: parent.width - 72
                                                wrapMode: Text.WrapAnywhere
                                                text: modelData[1] || "—"
                                                color: Theme.textSecondary
                                                font.family: Theme.monoFont
                                                font.pixelSize: Theme.fontSizeSmall
                                            }
                                        }
                                    }
                                }
                            }

                            // Disconnected.
                            Text {
                                visible: current.mode === "disconnected"
                                width: parent.width
                                elide: Text.ElideRight
                                text: "Not connected" + (root.svc.lastSsid ? ` · Last: ${root.svc.lastSsid}` : "")
                                color: Theme.textSecondary
                                font.family: Theme.sansFont
                                font.pixelSize: Theme.fontSize
                            }

                            Text {
                                visible: root.svc.failure !== ""
                                width: parent.width
                                wrapMode: Text.Wrap
                                text: root.svc.failure
                                color: Theme.error
                                font.family: Theme.sansFont
                                font.pixelSize: Theme.fontSize
                            }

                            ActionButton {
                                visible: current.mode === "connected"
                                text: "Disconnect"
                                onClicked: root.svc.disconnect()
                            }

                            ActionButton {
                                visible: current.mode === "disconnected" && (root.svc.profile !== "" || root.svc.lastProfile !== "")
                                primary: true
                                text: "Reconnect"
                                onClicked: root.svc.reconnect()
                            }
                        }
                    }

                    // ---- 4. Networks ----
                    Column {
                        visible: root.svc.radioOn
                        width: parent.width
                        spacing: 6

                        Item {
                            width: parent.width
                            implicitHeight: 22

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "NETWORKS"
                                    color: Theme.textDisabled
                                    font.family: Theme.sansFont
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.letterSpacing: 0.8
                                }

                                Spinner {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: root.svc.scanning
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: root.svc.scanning
                                    text: "Scanning…"
                                    color: Theme.textDisabled
                                    font.family: Theme.sansFont
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }

                            ActionButton {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                small: true
                                enabled: !root.svc.scanning
                                text: "Scan"
                                onClicked: root.svc.scan()
                            }
                        }

                        Text {
                            visible: !root.svc.scanning && root.svc.networks.length === 0
                            text: "No other networks found"
                            color: Theme.textDisabled
                            font.family: Theme.sansFont
                            font.pixelSize: Theme.fontSize
                        }

                        Repeater {
                            model: root.svc.networks

                            delegate: NetworkRow {
                                required property var modelData
                                width: parent.width
                                net: modelData
                                owner: root
                            }
                        }
                    }

                    // ---- 5. Tailscale ----
                    Rectangle {
                        width: parent.width
                        height: Theme.borderWidth
                        color: Theme.border
                    }

                    Item {
                        width: parent.width
                        implicitHeight: tsText.implicitHeight

                        Column {
                            id: tsText
                            anchors.left: parent.left
                            anchors.right: tsToggle.left
                            anchors.rightMargin: 10
                            spacing: 2

                            Text {
                                text: "Tailscale"
                                color: Theme.textPrimary
                                font.family: Theme.sansFont
                                font.pixelSize: Theme.fontSize
                            }

                            Text {
                                width: parent.width
                                wrapMode: Text.Wrap
                                text: root.svc.tailscaleError !== "" ? root.svc.tailscaleError
                                    : root.svc.tailscaleBusy ? "Applying…"
                                    : root.svc.tailscaleUp ? `Running · ${root.svc.tailscaleIp}`
                                    : root.svc.tailscaleState === "" ? "Unavailable"
                                    : root.svc.tailscaleState === "NeedsLogin" ? "Needs login (tailscale up)"
                                    : root.svc.tailscaleState
                                color: root.svc.tailscaleError !== "" ? Theme.error : Theme.textDisabled
                                font.family: Theme.monoFont
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }

                        Toggle {
                            id: tsToggle
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            checked: root.svc.tailscaleUp
                            enabled: !root.svc.tailscaleBusy && root.svc.tailscaleState !== ""
                            onToggled: root.svc.setTailscale(!root.svc.tailscaleUp)
                        }
                    }
                }
            }
        }
    }

    // ---- Network row ----------------------------------------------------------
    // Inline components can't see this file's ids, so the row gets the popover state
    // (expandedSsid, confirmForget) through `owner`.
    component NetworkRow: Rectangle {
        id: row

        property var net
        property var owner
        readonly property bool expanded: owner.expandedSsid === net.ssid
        readonly property bool confirming: owner.confirmForget === net.ssid
        readonly property bool secured: net.security !== "open"
        property string error: ""
        property bool showPassword: false // the eye in the password field

        implicitHeight: rowColumn.implicitHeight
        radius: Theme.radiusSmall
        color: expanded ? Theme.inset : rowHover.hovered ? Theme.hover : "transparent"

        function submit() {
            if (net.security === "EAP") return;
            const pw = secured && !net.saved ? password.text : "";
            if (secured && !net.saved && (pw.length < 8 || pw.length > 63)) {
                error = "Passwords are 8–63 characters.";
                return;
            }
            error = "";
            password.text = "";
            showPassword = false;
            if (net.saved) WifiService.switchTo(net.profile);
            else WifiService.join(net.ssid, pw);
            owner.expandedSsid = "";
        }

        onExpandedChanged: {
            error = "";
            password.text = "";
            showPassword = false;
            if (expanded && secured && !net.saved) password.forceActiveFocus();
        }

        Column {
            id: rowColumn
            width: parent.width

            // Header line.
            Item {
                width: parent.width
                height: 32

                HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        row.owner.confirmForget = "";
                        row.owner.expandedSsid = row.expanded ? "" : row.net.ssid;
                    }
                }

                WifiGlyph {
                    id: rowGlyph
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    size: 14
                    level: row.net.level
                    color: Theme.textSecondary
                }

                Text {
                    anchors.left: rowGlyph.right
                    anchors.leftMargin: 10
                    anchors.right: rowMeta.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: row.net.ssid
                    color: Theme.textPrimary
                    font.family: Theme.sansFont
                    font.pixelSize: Theme.fontSize
                }

                Row {
                    id: rowMeta
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Pill {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.net.saved
                        text: "saved"
                        accent: true
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.net.bands.join("/")
                        color: Theme.textDisabled
                        font.family: Theme.monoFont
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    AppGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "lock"
                        size: 11
                        color: row.secured ? Theme.textSecondary : "transparent"
                    }
                }
            }

            // Expanded actions.
            Column {
                visible: row.expanded
                x: 10
                width: parent.width - 20
                topPadding: 2
                bottomPadding: 10
                spacing: 8

                // Saved: connect / forget (with inline confirmation).
                Row {
                    visible: row.net.saved && !row.confirming
                    spacing: 8

                    ActionButton {
                        primary: true
                        text: "Connect"
                        enabled: !WifiService.helperBusy
                        onClicked: row.submit()
                    }

                    ActionButton {
                        text: "Forget"
                        enabled: !WifiService.helperBusy
                        onClicked: row.owner.confirmForget = row.net.ssid
                    }
                }

                Text {
                    visible: row.net.saved && !row.confirming
                    width: parent.width
                    elide: Text.ElideRight
                    text: `iwctl station ${WifiService.iface} connect "${row.net.ssid}"`
                    color: Theme.textDisabled
                    font.family: Theme.monoFont
                    font.pixelSize: Theme.fontSizeSmall
                }

                Text {
                    visible: row.confirming
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: `Forget "${row.net.ssid}"? Its saved password is removed too.`
                    color: Theme.textSecondary
                    font.family: Theme.sansFont
                    font.pixelSize: Theme.fontSize
                }

                Row {
                    visible: row.confirming
                    spacing: 8

                    ActionButton {
                        danger: true
                        text: "Forget"
                        onClicked: {
                            WifiService.forget(row.net.profile);
                            row.owner.confirmForget = "";
                            row.owner.expandedSsid = "";
                        }
                    }

                    ActionButton {
                        text: "Cancel"
                        onClicked: row.owner.confirmForget = ""
                    }
                }

                // New network.
                Text {
                    visible: !row.net.saved && (!row.secured || row.net.security === "EAP")
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: row.net.security === "EAP" ? "Enterprise (802.1X) networks can't be joined from here."
                        : "Open network, traffic is not encrypted."
                    color: Theme.textDisabled
                    font.family: Theme.sansFont
                    font.pixelSize: Theme.fontSize
                }

                Row {
                    visible: !row.net.saved && row.net.security !== "EAP"
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        visible: row.secured
                        width: parent.width - joinButton.width - parent.spacing
                        height: 28
                        radius: Theme.radiusSmall
                        color: Theme.base
                        border.width: Theme.borderWidth
                        border.color: password.activeFocus ? Theme.alpha(Theme.accent, 0.5) : Theme.border

                        TextInput {
                            id: password
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10 + eyeButton.width + 4
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: row.showPassword ? TextInput.Normal : TextInput.Password
                            maximumLength: 63
                            clip: true
                            color: Theme.textPrimary
                            selectionColor: Theme.accentBg
                            font.family: Theme.monoFont
                            font.pixelSize: Theme.fontSize
                            onAccepted: row.submit()
                            Keys.onEscapePressed: row.owner.expandedSsid = ""

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: password.text === ""
                                text: "Password"
                                color: Theme.textDisabled
                                font.family: Theme.sansFont
                                font.pixelSize: Theme.fontSize
                            }
                        }

                        // Show / hide the password; typing focus stays in the field.
                        Item {
                            id: eyeButton
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            height: 20

                            AppGlyph {
                                anchors.centerIn: parent
                                kind: row.showPassword ? "eyeOff" : "eye"
                                size: 14
                                color: eyeMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                            }

                            MouseArea {
                                id: eyeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    row.showPassword = !row.showPassword;
                                    password.forceActiveFocus();
                                }
                            }
                        }
                    }

                    ActionButton {
                        id: joinButton
                        primary: true
                        text: "Join"
                        enabled: !WifiService.helperBusy
                        onClicked: row.submit()
                    }
                }

                Text {
                    visible: row.error !== ""
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: row.error
                    color: Theme.error
                    font.family: Theme.sansFont
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }

    // ---- Pieces ------------------------------------------------------------
    // Label + current rate above a 30px sparkline.
    component Rate: Column {
        id: rate
        property string label
        property real rate: 0
        property var values: []
        property color lineColor

        spacing: 4

        Item {
            width: parent.width
            implicitHeight: rateValue.implicitHeight

            Text {
                anchors.baseline: rateValue.baseline
                text: rate.label
                color: Theme.textDisabled
                font.family: Theme.sansFont
                font.pixelSize: Theme.fontSizeSmall
            }

            Text {
                id: rateValue
                anchors.right: parent.right
                text: WifiService.formatRate(rate.rate)
                color: Theme.textPrimary
                font.family: Theme.monoFont
                font.pixelSize: Theme.fontSize
                font.features: { "tnum": 1 }
            }
        }

        Sparkline {
            width: parent.width
            height: 30
            samples: WifiService.historyLength
            values: rate.values
            maxValue: Math.max(64 * 1024, ...rate.values) * 1.15
            lineColor: rate.lineColor
        }
    }

    // Small rounded tag.
    component Pill: Rectangle {
        id: pill
        property string text
        property bool accent: false

        implicitWidth: pillText.implicitWidth + 14
        implicitHeight: 20
        radius: Theme.radiusSmall
        color: accent ? Theme.accentBg : Theme.hover
        border.width: accent ? 0 : Theme.borderWidth
        border.color: Theme.borderSubtle

        Text {
            id: pillText
            anchors.centerIn: parent
            text: pill.text
            color: pill.accent ? Theme.accent : Theme.textSecondary
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    // Text button: secondary by default, `primary` = lime gradient, `danger` = coral.
    component ActionButton: Rectangle {
        id: button
        property string text
        property bool primary: false
        property bool danger: false
        property bool small: false
        signal clicked()

        implicitWidth: buttonText.implicitWidth + (small ? 16 : 24)
        implicitHeight: small ? 22 : 28
        radius: Theme.radiusSmall
        opacity: enabled ? 1 : 0.4
        color: danger ? Theme.alpha(Theme.error, buttonHover.hovered ? 0.25 : 0.15)
             : buttonHover.hovered ? Theme.track : Theme.raisedHigh
        gradient: primary ? primaryGradient : null
        border.width: primary || danger ? 0 : Theme.borderWidth
        border.color: Theme.border

        AccentGradient { id: primaryGradient }

        Text {
            id: buttonText
            anchors.centerIn: parent
            text: button.text
            color: button.primary ? Theme.textOnAccent : button.danger ? Theme.error : Theme.textPrimary
            font.family: Theme.sansFont
            font.pixelSize: button.small ? Theme.fontSizeSmall : Theme.fontSize
        }

        HoverHandler { id: buttonHover; enabled: button.enabled; cursorShape: Qt.PointingHandCursor }
        TapHandler { enabled: button.enabled; onTapped: button.clicked() }
    }

    // 34 × 20 switch, like the battery charge-limit toggle.
    component Toggle: Rectangle {
        id: toggle
        property bool checked: false
        signal toggled()

        width: 34
        height: 20
        radius: 10
        opacity: enabled ? 1 : 0.4
        color: checked ? Theme.accent : Theme.track
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        Rectangle {
            x: toggle.checked ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            radius: 7
            color: toggle.checked ? Theme.textOnAccent : Theme.textSecondary
            Behavior on x { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic } }
        }

        HoverHandler { enabled: toggle.enabled; cursorShape: Qt.PointingHandCursor }
        TapHandler { enabled: toggle.enabled; onTapped: toggle.toggled() }
    }

    // Small rotating arc.
    component Spinner: Shape {
        id: spinner
        width: 10
        height: 10
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.textDisabled
            strokeWidth: 1.5
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: 5; centerY: 5; radiusX: 4; radiusY: 4; startAngle: 0; sweepAngle: 270; moveToStart: true }
        }

        RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            running: spinner.visible
        }
    }
}
