// TailscaleChip.qml: bar chip (Tailscale's nine dots, lit when connected, amber when signed
// out) and a panel: state + on/off switch, this machine's name and address, the other
// machines on the tailnet (online first; click one to copy its name, e.g. for ssh or
// herdr), and the admin console. Data: TailscaleService.
// Only one bar popup at a time (PopupManager).
import QtQuick
import Quickshell

Item {
    id: root

    readonly property bool open: panel.open
    readonly property var svc: TailscaleService

    implicitWidth: chip.implicitWidth
    implicitHeight: chip.implicitHeight

    Binding { target: TailscaleService; property: "panelOpen"; value: panel.open }

    // "Copied" feedback: which value was copied last, for a moment.
    property string copied: ""
    function copy(text) {
        Quickshell.clipboardText = text;
        copied = text;
        copiedReset.restart();
    }
    Timer { id: copiedReset; interval: 1500; onTriggered: root.copied = "" }

    // ---- Chip ------------------------------------------------------------------------------
    Rectangle {
        id: chip

        implicitWidth: Theme.barIconSize + Theme.barChipPadding * 2
        implicitHeight: Theme.barChipHeight
        radius: Theme.radiusSmall
        color: (chipMouse.containsMouse || PopupManager.hovers(chipMouse)) || root.open ? Theme.chipHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        TailnetGlyph {
            anchors.centerIn: parent
            size: Theme.barIconSize - 2
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: panel.toggle()
        }
    }

    // ---- Panel ---------------------------------------------------------------------------------
    BarPopup {
        id: panel
        anchorItem: chip
        align: "right"

        function toggle() { if (open) close(); else if (!PopupManager.justClosed("tailscale")) show(); }
        function show() {
            TailscaleService.refresh();
            PopupManager.opened("tailscale");
            visible = true; fadeInDelay.restart();
        }
        function close() { fadeInDelay.stop(); open = false; PopupManager.closed("tailscale"); hideAfterFade.restart(); }

        Connections {
            target: PopupManager
            function onCurrentChanged() { if (panel.visible && PopupManager.current !== "tailscale") panel.close(); }
        }

        cardWidth: 340
        cardHeight: card.implicitHeight
        color: "transparent"
        visible: false

        // Map the window with the card still transparent and start the fade-in a frame
        // later, so the window's very first frame shows nothing (no stale-frame flash).
        Timer { id: fadeInDelay; interval: 16; onTriggered: { panel.open = true; card.forceActiveFocus(); } }

        Timer { id: hideAfterFade; interval: Theme.durationNormal; onTriggered: if (!panel.open) panel.visible = false }

        Rectangle {
            id: card

            width: parent.width
            implicitHeight: content.implicitHeight + Theme.popupPadding * 2
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

            Column {
                id: content
                x: Theme.popupPadding
                y: Theme.popupPadding
                width: parent.width - Theme.popupPadding * 2
                spacing: Theme.popupSpacing

                // ---- 1. Header: state + switch ----
                Item {
                    width: parent.width
                    implicitHeight: header.implicitHeight

                    Row {
                        id: header
                        anchors.left: parent.left
                        anchors.right: upToggle.left
                        anchors.rightMargin: 10
                        spacing: 12

                        TailnetGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            size: 26
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: header.width - 26 - header.spacing
                            spacing: 2

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: root.svc.headline
                                color: root.svc.status === "login" ? Theme.warning : Theme.textPrimary
                                font.family: Theme.sansFont
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                            }

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: root.svc.subline
                                color: Theme.textSecondary
                                font.family: Theme.monoFont
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }

                    Toggle {
                        id: upToggle
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        checked: root.svc.up
                        enabled: !root.svc.busy && root.svc.status !== "unavailable"
                        onToggled: root.svc.setUp(!root.svc.up)
                    }
                }

                Text {
                    visible: root.svc.error !== ""
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: root.svc.error
                    color: Theme.error
                    font.family: Theme.monoFont
                    font.pixelSize: Theme.fontSizeSmall
                }

                // ---- 2. This machine (click a value to copy it) ----
                Column {
                    visible: root.svc.up
                    width: parent.width
                    spacing: 2

                    CopyRow { label: "Address"; value: root.svc.ip }
                    CopyRow { label: "Name"; value: root.svc.dnsName }
                }

                // ---- 3. Other machines ----
                Column {
                    visible: root.svc.up && root.svc.peers.length > 0
                    width: parent.width
                    spacing: 4

                    Item {
                        width: parent.width
                        implicitHeight: machinesLabel.implicitHeight

                        Text {
                            id: machinesLabel
                            text: "Machines"
                            color: Theme.textSecondary
                            font.family: Theme.sansFont
                            font.pixelSize: Theme.fontSize
                        }

                        Text {
                            anchors.right: parent.right
                            text: `${root.svc.peersOnline} of ${root.svc.peers.length} online`
                            color: Theme.textPrimary
                            font.family: Theme.monoFont
                            font.pixelSize: Theme.fontSize
                            font.features: { "tnum": 1 }
                        }
                    }

                    Repeater {
                        // Keyed by name, so rows persist across the 3 s refresh (no hover flicker).
                        model: ScriptModel {
                            values: root.svc.peers
                            objectProp: "name"
                        }

                        PeerRow {
                            required property var modelData
                            width: parent.width
                            peer: modelData
                        }
                    }
                }

                // ---- 4. Admin console ----
                ActionButton {
                    width: parent.width
                    glyph: "external"
                    label: "Admin console"
                    onClicked: { root.svc.openAdmin(); panel.close(); }
                }
            }
        }
    }

    // ---- Pieces --------------------------------------------------------------------------------------
    // Tailscale's mark: a 3x3 grid of dots, the middle row and bottom centre lit. In the
    // state's colour; all dim while unavailable or off.
    component TailnetGlyph: Item {
        id: tailnetGlyph
        property int size: Theme.barIconSize
        implicitWidth: size
        implicitHeight: size

        readonly property real dot: size / 4.2
        readonly property real gap: (size - dot * 3) / 2
        readonly property bool lit: root.svc.status === "up" || root.svc.status === "login" || root.svc.status === "busy"

        Repeater {
            model: 9

            Rectangle {
                required property int index
                readonly property int col: index % 3
                readonly property int row: Math.floor(index / 3)
                readonly property bool mark: row === 1 || (row === 2 && col === 1)

                x: col * (tailnetGlyph.dot + tailnetGlyph.gap)
                y: row * (tailnetGlyph.dot + tailnetGlyph.gap)
                width: tailnetGlyph.dot
                height: tailnetGlyph.dot
                radius: width / 2
                color: root.svc.statusColor
                opacity: tailnetGlyph.lit && mark ? 1 : 0.3
                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
            }
        }
    }

    // Label on the left, value on the right; click copies the value.
    component CopyRow: Rectangle {
        id: copyRow
        property string label
        property string value
        width: parent.width
        implicitHeight: 24
        radius: Theme.radiusSmall
        color: copyMouse.containsMouse ? Theme.hover : "transparent"

        Text {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            text: copyRow.label
            color: Theme.textDisabled
            font.family: Theme.sansFont
            font.pixelSize: Theme.fontSize
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width - 90)
            elide: Text.ElideMiddle
            horizontalAlignment: Text.AlignRight
            text: root.copied === copyRow.value && copyRow.value !== "" ? "Copied" : copyRow.value
            color: root.copied === copyRow.value ? Theme.accent : Theme.textPrimary
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontSize
        }

        MouseArea {
            id: copyMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (copyRow.value !== "") root.copy(copyRow.value)
        }
    }

    // Dot + name; address and path (direct / relay) or when it was last seen. Click copies
    // its MagicDNS name.
    component PeerRow: Rectangle {
        id: peerRow
        property var peer
        readonly property string copyValue: peer.dnsName.split(".")[0] || peer.ip
        implicitHeight: 26
        radius: Theme.radiusSmall
        color: peerMouse.containsMouse ? Theme.hover : "transparent"

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: 6
            width: 8
            height: 8
            radius: 4
            color: peerRow.peer.online ? Theme.accent : "transparent"
            border.width: peerRow.peer.online ? 0 : 1.5
            border.color: Theme.textDisabled
        }

        Text {
            id: peerName
            anchors.verticalCenter: parent.verticalCenter
            x: 22
            width: Math.min(implicitWidth, parent.width - 22 - peerDetail.implicitWidth - 16)
            elide: Text.ElideRight
            text: peerRow.peer.name
            color: peerRow.peer.online ? Theme.textPrimary : Theme.textSecondary
            font.family: Theme.sansFont
            font.pixelSize: Theme.fontSize
        }

        Text {
            id: peerDetail
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            readonly property var p: peerRow.peer
            text: root.copied === peerRow.copyValue ? "Copied"
                : p.online ? [p.ip, p.link].filter(s => s !== "").join(" · ")
                : `seen ${root.svc.ago(p.lastSeen)}`
            color: root.copied === peerRow.copyValue ? Theme.accent : Theme.textDisabled
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontSizeSmall
            font.features: { "tnum": 1 }
        }

        MouseArea {
            id: peerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.copy(peerRow.copyValue)
        }
    }

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

        MouseArea {
            anchors.fill: parent
            enabled: toggle.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.toggled()
        }
    }

    component ActionButton: Rectangle {
        id: button
        property string glyph
        property string label
        signal clicked()

        implicitHeight: 30
        radius: Theme.radiusSmall
        opacity: enabled ? 1 : 0.4
        color: buttonMouse.containsMouse ? Theme.raisedHigh : Theme.inset
        border.width: Theme.borderWidth
        border.color: Theme.borderSubtle
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        Row {
            anchors.centerIn: parent
            spacing: 6

            AppGlyph {
                anchors.verticalCenter: parent.verticalCenter
                kind: button.glyph
                size: 12
                color: Theme.textSecondary
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: button.label
                color: Theme.textPrimary
                font.family: Theme.sansFont
                font.pixelSize: Theme.fontSize
            }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
