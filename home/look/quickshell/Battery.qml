// Battery.qml: bar chip (battery icon + %) and a panel with readings, where power goes,
// a 6 h charge chart, CPU profile and the 80 % charge limit. Data: BatteryService.
// Only one bar popup at a time (PopupManager).
import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    readonly property bool open: panel.open
    readonly property var svc: BatteryService

    implicitWidth: chip.implicitWidth
    implicitHeight: chip.implicitHeight

    // ---- Chip ------------------------------------------------------------------------------
    Rectangle {
        id: chip

        implicitWidth: row.implicitWidth + Theme.barChipPadding * 2
        implicitHeight: Theme.barChipHeight
        radius: Theme.radiusSmall
        color: chipMouse.containsMouse || root.open ? Theme.chipHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6

            BatteryIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 25
                height: 14
                level: root.svc.percent / 100
                charging: root.svc.charging
                color: root.svc.levelColor
                cutoutColor: Theme.base
            }
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
    PopupWindow {
        id: panel

        property bool open: false
        function toggle() { if (open) close(); else if (!PopupManager.justClosed("battery")) show(); }
        function show() {
            BatteryService.refreshAll();
            PopupManager.opened("battery");
            visible = true; fadeInDelay.restart();
        }
        function close() { fadeInDelay.stop(); open = false; PopupManager.closed("battery"); hideAfterFade.restart(); }

        Connections {
            target: PopupManager
            function onCurrentChanged() { if (panel.visible && PopupManager.current !== "battery") panel.close(); }
        }

        anchor.item: chip
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.bottom: -Theme.popupGap // margins resize the anchor rect; negative = below it

        implicitWidth: 350
        implicitHeight: card.implicitHeight
        color: "transparent"
        visible: false

        // Map the window with the card still transparent and start the fade-in a frame
        // later, so the window's very first frame shows nothing (no stale-frame flash).
        Timer { id: fadeInDelay; interval: 16; onTriggered: { panel.open = true; card.forceActiveFocus(); } }

        Timer { id: hideAfterFade; interval: Theme.durationNormal; onTriggered: if (!panel.open) panel.visible = false }

        HyprlandFocusGrab {
            windows: [panel]
            active: panel.visible
            onCleared: panel.close()
        }

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

                // ---- 1. Header ----
                Row {
                    spacing: 14

                    BatteryIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 46
                        height: 24
                        level: root.svc.percent / 100
                        charging: root.svc.charging
                        color: root.svc.levelColor
                        cutoutColor: Theme.raised
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            id: bigPercent
                            text: root.svc.percent
                            color: Theme.textPrimary
                            font.family: Theme.monoFont
                            font.pixelSize: Theme.fontSizeXL
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                        }

                        Text {
                            anchors.baseline: bigPercent.baseline
                            text: "%"
                            color: Theme.textSecondary
                            font.family: Theme.monoFont
                            font.pixelSize: Theme.fontSizeLarge
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: root.svc.stateLine
                            color: root.svc.charging ? Theme.accent : Theme.textPrimary
                            font.family: Theme.sansFont
                            font.pixelSize: Theme.fontSizeTitle
                        }

                        Text {
                            visible: text !== ""
                            text: root.svc.timeLine
                            color: Theme.textSecondary
                            font.family: Theme.monoFont
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }

                // ---- 2. Readings (3 × 2) ----
                Grid {
                    id: readings
                    width: parent.width
                    columns: 3
                    rowSpacing: 10
                    columnSpacing: 8

                    Reading { label: "Draw"; value: `${root.svc.draw.toFixed(1)} W` }
                    Reading { label: "Energy"; value: `${root.svc.energy.toFixed(1)} / ${root.svc.energyFull.toFixed(1)} Wh` }
                    Reading {
                        label: "Health"
                        value: root.svc.designEnergy > 0 ? `${Math.round(root.svc.health)}% of ${Math.round(root.svc.designEnergy)} Wh`
                                                       : `${Math.round(root.svc.health)}%`
                    }
                    Reading { label: "Cycles"; value: `${root.svc.cycles}` }
                    Reading { label: "Temp"; value: Number.isFinite(root.svc.temperature) ? `${root.svc.temperature.toFixed(1)} °C` : "–" }
                    Reading { label: "Voltage"; value: root.svc.voltage > 0 ? `${root.svc.voltage.toFixed(2)} V` : "–" }
                }

                // ---- 3. Where power goes ----
                Column {
                    id: split
                    width: parent.width
                    spacing: 6

                    readonly property real total: Number.isFinite(root.svc.totalPower) ? root.svc.totalPower : 0
                    readonly property real soc: Number.isFinite(root.svc.socPower) ? Math.min(root.svc.socPower, total) : 0
                    readonly property real rest: Math.max(0, total - soc)

                    HeaderRow { label: "Where power goes"; value: `${split.total.toFixed(1)} W` }

                    Item {
                        width: parent.width
                        height: 6

                        readonly property real usable: width - 2
                        Rectangle {
                            id: socBar
                            width: split.total > 0 ? parent.usable * split.soc / split.total : 0
                            height: parent.height
                            radius: 3
                            color: Theme.accent
                        }
                        Rectangle {
                            x: socBar.width + (socBar.width > 0 ? 2 : 0)
                            width: split.total > 0 ? parent.usable * split.rest / split.total : parent.width
                            height: parent.height
                            radius: 3
                            color: split.total > 0 ? Theme.alpha(Theme.textSecondary, 0.55) : Theme.track
                        }
                    }

                    Row {
                        spacing: 14
                        Legend { swatch: Theme.accent; text: `SoC ${split.soc.toFixed(1)} W` }
                        Legend { swatch: Theme.alpha(Theme.textSecondary, 0.55); text: `Rest of system ${split.rest.toFixed(1)} W` }
                    }
                }

                // ---- 4. Charge · last 6 h ----
                Column {
                    width: parent.width
                    spacing: 6

                    HeaderRow { label: "Charge · last 6 h"; value: "" }

                    ChargeChart {
                        width: parent.width
                        points: root.svc.history
                        current: root.svc.percent
                        active: panel.open
                    }
                }

                // ---- 5. CPU profile (on hosts that show it here, Host.cpuProfile) ----
                CpuProfileCard {
                    visible: Host.cpuProfile === "battery"
                    width: parent.width
                }

                // ---- 6. Charge limit ----
                Item {
                    visible: root.svc.limitSupported
                    width: parent.width
                    implicitHeight: limitText.implicitHeight

                    Column {
                        id: limitText
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: `Limit charge to ${root.svc.limitEnd}%`
                            color: Theme.textPrimary
                            font.family: Theme.sansFont
                            font.pixelSize: Theme.fontSize
                        }

                        Text {
                            text: root.svc.limitEnabled
                                ? `Stops at ${root.svc.limitEnd}%, resumes below ${root.svc.limitStart}%`
                                : "Charges to 100% now"
                            color: Theme.textDisabled
                            font.family: Theme.monoFont
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    // 34 × 20 switch.
                    Rectangle {
                        id: toggle
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        height: 20
                        radius: 10
                        color: root.svc.limitEnabled ? Theme.accent : Theme.track
                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                        Rectangle {
                            x: root.svc.limitEnabled ? parent.width - width - 3 : 3
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14
                            height: 14
                            radius: 7
                            color: root.svc.limitEnabled ? Theme.textOnAccent : Theme.textSecondary
                            Behavior on x { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.svc.setLimit(!root.svc.limitEnabled)
                        }
                    }
                }
            }
        }
    }

    // ---- Pieces --------------------------------------------------------------------------------------
    component Reading: Column {
        property string label
        property string value
        width: (readings.width - readings.columnSpacing * 2) / 3
        spacing: 2

        Text {
            text: parent.label
            color: Theme.textDisabled
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontSizeSmall
            font.capitalization: Font.AllUppercase
        }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: parent.value
            color: Theme.textPrimary
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontSize
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
        }
    }

    component HeaderRow: Item {
        property string label
        property string value
        width: parent.width
        implicitHeight: headerLabel.implicitHeight

        Text {
            id: headerLabel
            text: parent.label
            color: Theme.textSecondary
            font.family: Theme.sansFont
            font.pixelSize: Theme.fontSize
        }

        Text {
            anchors.right: parent.right
            text: parent.value
            color: Theme.textPrimary
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontSize
            font.features: { "tnum": 1 }
        }
    }

    component Legend: Row {
        property color swatch
        property string text
        spacing: 5

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 2
            color: parent.swatch
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.text
            color: Theme.textSecondary
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
