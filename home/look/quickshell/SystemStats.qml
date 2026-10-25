// SystemStats.qml: bar chip (a CPU icon) and a panel with 5-minute charts
// (CPU + per-core bars, SoC power, temperature, memory) and disk usage. Data: StatsService.
import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    readonly property bool open: panel.open

    implicitWidth: chip.implicitWidth
    implicitHeight: chip.implicitHeight

    // ---- Chip ----------------------------------------------------------------------------
    Rectangle {
        id: chip

        implicitWidth: icon.implicitWidth + Theme.barChipPadding * 2
        implicitHeight: Theme.barChipHeight
        radius: Theme.radiusSmall
        color: (chipMouse.containsMouse || PopupManager.hovers(chipMouse)) || root.open ? Theme.chipHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        AppGlyph {
            id: icon
            anchors.centerIn: parent
            kind: "chip"
            size: Theme.barIconSize
            color: Theme.accent
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: panel.toggle()
        }
    }

    // ---- Panel -----------------------------------------------------------------------------
    BarPopup {
        id: panel
        anchorItem: chip
        align: "right"

        function toggle() { if (open) close(); else if (!PopupManager.justClosed("stats")) show(); }
        function show() { PopupManager.opened("stats"); visible = true; fadeInDelay.restart(); }
        function close() { fadeInDelay.stop(); open = false; PopupManager.closed("stats"); hideAfterFade.restart(); }

        // Only one bar popup at a time (PopupManager).
        Connections {
            target: PopupManager
            function onCurrentChanged() { if (panel.visible && PopupManager.current !== "stats") panel.close(); }
        }

        // Charts repaint only while open.
        Binding { target: StatsService; property: "panelOpen"; value: panel.open }
        // Re-read the CPU profile each time the panel opens (it may change elsewhere).
        onOpenChanged: if (open && Host.cpuProfile === "stats") CpuProfileService.readProfile()

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

                // ---- Header ----
                Row {
                    spacing: 10

                    Rectangle {
                        width: 34
                        height: 34
                        radius: Theme.radiusSmall
                        color: Theme.accentBg

                        AppGlyph {
                            anchors.centerIn: parent
                            kind: "chip"
                            size: 18
                            color: Theme.accent
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: Host.machineName
                            color: Theme.textPrimary
                            font.family: Theme.sansFont
                            font.pixelSize: Theme.fontSizeTitle
                        }

                        Text {
                            text: [Host.machineCores, `${StatsService.memInstalled} GB`, Host.machineNotes].filter(x => x).join(" · ")
                            color: Theme.textDisabled
                            font.family: Theme.monoFont
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }

                // ---- CPU ----
                Section {
                    label: "CPU"
                    value: `${Math.round(StatsService.cpu)}%`

                    StatsChart {
                        width: parent.width
                        values: StatsService.cpuHistory
                        maxValue: 100
                        lineColor: Theme.accent
                        format: v => `${Math.round(v)}%`
                        active: panel.open
                    }

                    // Per-core bars: E-cores grey (E1…), P-cores lime (P1…); plain cores lime (1…).
                    Row {
                        id: cores
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: Host.coreCount

                            delegate: Column {
                                id: core
                                required property int index
                                readonly property bool eCore: StatsService.eCores.includes(index)
                                readonly property real load: StatsService.coreLoads[index] ?? 0
                                width: (cores.width - cores.spacing * (Host.coreCount - 1)) / Host.coreCount
                                spacing: 4

                                Rectangle {
                                    width: parent.width
                                    height: 32
                                    radius: 3
                                    color: Theme.track

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: Math.max(core.load > 0 ? 2 : 0, parent.height * core.load / 100)
                                        radius: 3
                                        color: core.eCore ? Theme.textSecondary : Theme.accent
                                        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: core.eCore ? `E${StatsService.eCores.indexOf(core.index) + 1}`
                                        : StatsService.eCores.length ? `P${core.index - StatsService.eCores.length + 1}` : `${core.index + 1}`
                                    color: Theme.textDisabled
                                    font.family: Theme.monoFont
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }
                        }
                    }
                }

                // ---- Power (where the machine has a power sensor) ----
                Section {
                    visible: Host.powerLabel !== ""
                    label: "Power"
                    sublabel: StatsService.hasPower ? StatsService.powerLabel : "sensor not found"
                    value: Number.isFinite(StatsService.power) ? `${StatsService.power.toFixed(1)} W` : "–"

                    StatsChart {
                        width: parent.width
                        values: StatsService.powerHistory
                        maxValue: StatsService.powerMax
                        lineColor: Theme.accent
                        format: v => `${v.toFixed(1)} W`
                        active: panel.open
                    }
                }

                // ---- Temperature ----
                Section {
                    id: tempSection
                    readonly property string status: StatsService.tempStatus(StatsService.temp)
                    readonly property color statusColor: status === "throttling" ? Theme.error
                                                       : status === "warm" ? Theme.warning
                                                       : Theme.textPrimary
                    label: "Temperature"
                    sublabel: StatsService.hasTemp ? StatsService.tempLabel : "sensor not found"
                    value: Number.isFinite(StatsService.temp) ? `${StatsService.temp.toFixed(1)} °C` : "–"
                    tag: status

                    StatsChart {
                        width: parent.width
                        values: StatsService.tempHistory
                        minValue: 30
                        maxValue: 105
                        threshold: StatsService.tempWarm
                        thresholdColor: Theme.warning
                        lineColor: tempSection.statusColor
                        format: v => `${v.toFixed(1)} °C`
                        active: panel.open
                    }
                }

                // ---- Memory ----
                Section {
                    label: "Memory"
                    value: `${StatsService.memUsed.toFixed(1)} / ${StatsService.memTotal.toFixed(1)} GB`

                    StatsChart {
                        width: parent.width
                        values: StatsService.memHistory
                        maxValue: StatsService.memTotal || 1
                        lineColor: Theme.textSecondary
                        format: v => `${v.toFixed(1)} GB`
                        active: panel.open
                    }
                }

                // ---- CPU profile (on hosts that show it here, Host.cpuProfile) ----
                CpuProfileCard {
                    visible: Host.cpuProfile === "stats"
                    width: parent.width
                }

                // ---- Disk ----
                Section {
                    id: diskSection
                    readonly property real used: StatsService.diskSize > 0 ? StatsService.diskUsed / (StatsService.diskUsed + StatsService.diskAvail) : 0
                    label: "Disk /"
                    value: StatsService.diskSize > 0
                        ? `${StatsService.bytes(StatsService.diskUsed)} / ${StatsService.bytes(StatsService.diskSize)}` : "–"

                    Rectangle {
                        width: parent.width
                        height: 6
                        radius: 3
                        color: Theme.track

                        Rectangle {
                            width: parent.width * diskSection.used
                            height: parent.height
                            radius: 3
                            color: diskSection.used >= 0.95 ? Theme.error
                                 : diskSection.used >= 0.85 ? Theme.warning
                                 : Theme.accent
                        }
                    }

                    Item {
                        width: parent.width
                        implicitHeight: usedText.implicitHeight

                        Text {
                            id: usedText
                            text: `${Math.round(diskSection.used * 100)}% used`
                            color: Theme.textSecondary
                            font.family: Theme.monoFont
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Text {
                            anchors.right: parent.right
                            text: `${StatsService.bytes(StatsService.diskAvail)} free`
                            color: Theme.textSecondary
                            font.family: Theme.monoFont
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }

                Text {
                    text: "Charts show the last 5 min · hover for exact values"
                    color: Theme.textDisabled
                    font.family: Theme.sansFont
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }

    // Label (+ optional sublabel) on the left; value (+ optional status tag) on the right;
    // children below.
    component Section: Column {
        id: section
        property string label
        property string sublabel
        property string value
        property string tag
        default property alias body: bodyColumn.data

        width: parent.width
        spacing: 8

        Item {
            width: parent.width
            implicitHeight: Math.max(labelColumn.implicitHeight, valueRow.implicitHeight)

            Column {
                id: labelColumn
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: section.label
                    color: Theme.textSecondary
                    font.family: Theme.sansFont
                    font.pixelSize: Theme.fontSize
                }

                Text {
                    visible: section.sublabel !== ""
                    text: section.sublabel
                    color: Theme.textDisabled
                    font.family: Theme.monoFont
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Row {
                id: valueRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    visible: section.tag !== "" && section.tag !== "unknown"
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property color tint: section.tag === "throttling" ? Theme.error
                                                : section.tag === "warm" ? Theme.warning
                                                : Theme.textSecondary
                    width: tagText.implicitWidth + 10
                    height: tagText.implicitHeight + 2
                    radius: Theme.radiusSmall
                    color: section.tag === "normal" ? Theme.raisedHigh : Theme.alpha(tint, 0.15)

                    Text {
                        id: tagText
                        anchors.centerIn: parent
                        text: section.tag
                        color: parent.tint
                        font.family: Theme.sansFont
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: section.value
                    color: Theme.textPrimary
                    font.family: Theme.monoFont
                    font.pixelSize: Theme.fontSize
                    font.features: { "tnum": 1 }
                }
            }
        }

        Column {
            id: bodyColumn
            width: parent.width
            spacing: 8
        }
    }
}
