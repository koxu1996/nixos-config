// Syncthing.qml: bar chip (sync glyph in the state's colour, spinning while syncing; the
// device count is left to the panel) and a panel: state, transfer rates, things that need attention
// (unshared folders, conflicts, pending devices, errors), folders, devices, and actions
// (rescan, pause/resume all, web UI). Data: SyncthingService.
// Only one bar popup at a time (PopupManager).
import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    readonly property bool open: panel.open
    readonly property var svc: SyncthingService

    implicitWidth: chip.implicitWidth
    implicitHeight: chip.implicitHeight

    Binding { target: SyncthingService; property: "panelOpen"; value: panel.open }

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
            spacing: 5

            SyncGlyph {
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.barIconSize
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
    BarPopup {
        id: panel
        anchorItem: chip
        align: "right"

        function toggle() { if (open) close(); else if (!PopupManager.justClosed("syncthing")) show(); }
        function show() {
            SyncthingService.refresh();
            PopupManager.opened("syncthing");
            visible = true; fadeInDelay.restart();
        }
        function close() { fadeInDelay.stop(); open = false; PopupManager.closed("syncthing"); hideAfterFade.restart(); }

        Connections {
            target: PopupManager
            function onCurrentChanged() { if (panel.visible && PopupManager.current !== "syncthing") panel.close(); }
        }

        cardWidth: 360
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

                // ---- 1. Header ----
                Row {
                    spacing: 12

                    SyncGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 28
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: root.svc.headline
                            color: root.svc.status === "ok" || root.svc.status === "syncing" ? Theme.textPrimary : root.svc.statusColor
                            font.family: Theme.sansFont
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                        }

                        Text {
                            text: root.svc.subline
                            color: Theme.textSecondary
                            font.family: Theme.monoFont
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }

                // Offline: only a way to the web UI.
                Text {
                    visible: !root.svc.reachable
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: root.svc.apiKey === "" ? `No API key in ${root.svc.configPath}`
                                                 : "Check the service: systemctl status syncthing"
                    color: Theme.textDisabled
                    font.family: Theme.monoFont
                    font.pixelSize: Theme.fontSizeSmall
                }

                // ---- 2. Readings ----
                Grid {
                    id: readings
                    visible: root.svc.reachable
                    width: parent.width
                    columns: 3
                    columnSpacing: 8

                    Reading { label: "Down"; value: `${root.svc.bytes(root.svc.inRate)}/s` }
                    Reading { label: "Up"; value: `${root.svc.bytes(root.svc.outRate)}/s` }
                    Reading { label: "Synced data"; value: root.svc.bytes(root.svc.totalBytes) }
                }

                // ---- 3. Needs attention ----
                Column {
                    visible: root.svc.reachable && notices.count > 0
                    width: parent.width
                    spacing: 6

                    Repeater {
                        id: notices
                        model: {
                            const s = root.svc, n = [];
                            for (const e of s.errors.slice(-3))
                                n.push({ tone: "error", title: e.message, detail: s.ago(e.when), path: "" });
                            for (const f of s.folderRows.filter(f => f.failed > 0 || f.state === "error"))
                                n.push({ tone: "error", title: `“${f.label}”: ${f.error || s.plural(f.failed, "file") + " failed to sync"}`, detail: f.path, path: f.path });
                            for (const f of s.unshared)
                                n.push({ tone: "warning", title: `“${f.label}” isn't shared with any device`, detail: "Web UI → Edit folder → Sharing", path: "" });
                            for (const p of s.conflicts.slice(0, 3))
                                n.push({ tone: "warning", title: `Conflict: ${p.split("/").pop()}`, detail: p.slice(0, p.lastIndexOf("/")), path: p.slice(0, p.lastIndexOf("/")) });
                            if (s.conflicts.length > 3)
                                n.push({ tone: "warning", title: `${s.conflicts.length - 3} more conflicts`, detail: "", path: "" });
                            for (const id in s.pendingDevices)
                                n.push({ tone: "warning", title: `${s.pendingDevices[id].name || id.slice(0, 7)} wants to connect`, detail: id.slice(0, 7), path: "" });
                            for (const id in s.pendingFolders)
                                n.push({ tone: "warning", title: `Folder “${id}” offered`, detail: Object.keys(s.pendingFolders[id].offeredBy ?? {}).map(d => s.nameOf(d)).join(", "), path: "" });
                            return n;
                        }

                        Notice {
                            required property var modelData
                            width: parent.width
                            tone: modelData.tone
                            title: modelData.title
                            detail: modelData.detail
                            path: modelData.path
                        }
                    }
                }

                // ---- 4. Folders ----
                Column {
                    visible: root.svc.reachable && root.svc.folderRows.length > 0
                    width: parent.width
                    spacing: 6

                    HeaderRow { label: "Folders"; value: `${root.svc.folderRows.length}` }

                    Repeater {
                        model: root.svc.folderRows

                        FolderRow {
                            required property var modelData
                            width: parent.width
                            folder: modelData
                        }
                    }
                }

                // ---- 5. Devices ----
                Column {
                    visible: root.svc.reachable && root.svc.peersTotal > 0
                    width: parent.width
                    spacing: 6

                    HeaderRow { label: "Devices"; value: `${root.svc.peersOnline} of ${root.svc.peersTotal} online` }

                    Repeater {
                        model: root.svc.deviceRows

                        DeviceRow {
                            required property var modelData
                            width: parent.width
                            device: modelData
                        }
                    }
                }

                // ---- 6. Actions ----
                Row {
                    id: actions
                    width: parent.width
                    spacing: 6

                    readonly property real buttonWidth: (width - spacing * 2) / 3

                    ActionButton {
                        width: actions.buttonWidth
                        enabled: root.svc.reachable
                        glyph: "sync"
                        label: "Rescan"
                        onClicked: root.svc.rescanAll()
                    }
                    ActionButton {
                        width: actions.buttonWidth
                        enabled: root.svc.reachable && root.svc.peersTotal > 0
                        glyph: root.svc.allPaused ? "play" : "pause"
                        label: root.svc.allPaused ? "Resume" : "Pause"
                        onClicked: root.svc.allPaused ? root.svc.resumeAll() : root.svc.pauseAll()
                    }
                    ActionButton {
                        width: actions.buttonWidth
                        glyph: "external"
                        label: "Web UI"
                        onClicked: { root.svc.openWebUi(); panel.close(); }
                    }
                }
            }
        }
    }

    // ---- Pieces --------------------------------------------------------------------------------------
    // The sync glyph in the state's colour; turns while syncing and settles upright after.
    component SyncGlyph: Item {
        id: syncGlyph
        property int size: Theme.barIconSize
        implicitWidth: size
        implicitHeight: size

        AppGlyph {
            id: turning
            anchors.fill: parent
            kind: "sync"
            size: syncGlyph.size
            color: root.svc.statusColor
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

            RotationAnimator on rotation {
                running: root.svc.status === "syncing"
                from: 0; to: 360
                duration: 1400
                loops: Animation.Infinite
                onRunningChanged: if (!running) turning.rotation = 0
            }
        }
    }

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

    // A tinted card: something to fix. Clicking one with a path opens that folder.
    component Notice: Rectangle {
        id: notice
        property string tone: "warning"
        property string title
        property string detail
        property string path
        readonly property color toneColor: tone === "error" ? Theme.error : Theme.warning

        implicitHeight: noticeText.implicitHeight + 16
        radius: Theme.radiusSmall
        color: noticeMouse.containsMouse && path !== "" ? Theme.alpha(toneColor, 0.16) : Theme.alpha(toneColor, 0.1)
        border.width: Theme.borderWidth
        border.color: Theme.alpha(toneColor, 0.25)

        Rectangle {
            x: 10
            y: 8 + (noticeTitle.implicitHeight - height) / 2
            width: 6
            height: 6
            radius: 3
            color: notice.toneColor
        }

        Column {
            id: noticeText
            x: 24
            y: 8
            width: parent.width - 34
            spacing: 2

            Text {
                id: noticeTitle
                width: parent.width
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: notice.title
                color: Theme.textPrimary
                font.family: Theme.sansFont
                font.pixelSize: Theme.fontSize
            }

            Text {
                visible: text !== ""
                width: parent.width
                elide: Text.ElideMiddle
                text: notice.detail
                color: Theme.textSecondary
                font.family: Theme.monoFont
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        MouseArea {
            id: noticeMouse
            anchors.fill: parent
            enabled: notice.path !== ""
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.svc.openFolder(notice.path); panel.close(); }
        }
    }

    // Label + state; path · files · size; who it's shared with; a progress bar while syncing.
    component FolderRow: Rectangle {
        id: folderRow
        property var folder
        readonly property bool syncing: folder.state.startsWith("sync")
        readonly property color stateColor: folder.state === "error" || folder.failed > 0 ? Theme.error
                                          : folder.paused ? Theme.textDisabled
                                          : syncing ? Theme.accent
                                          : folder.state === "idle" ? Theme.textSecondary
                                          : Theme.textPrimary

        implicitHeight: folderCol.implicitHeight + 20
        radius: Theme.radiusSmall
        color: folderMouse.containsMouse ? Theme.raisedHigh : Theme.inset
        border.width: Theme.borderWidth
        border.color: Theme.borderSubtle
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        MouseArea {
            id: folderMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.svc.openFolder(folderRow.folder.path); panel.close(); }
        }

        Column {
            id: folderCol
            x: 12
            y: 10
            width: parent.width - 24
            spacing: 4

            Item {
                width: parent.width
                implicitHeight: folderName.implicitHeight

                Row {
                    spacing: 7

                    AppGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "folder"
                        size: Theme.iconSize
                        color: Theme.textSecondary
                    }

                    Text {
                        id: folderName
                        anchors.verticalCenter: parent.verticalCenter
                        text: folderRow.folder.label
                        color: Theme.textPrimary
                        font.family: Theme.sansFont
                        font.pixelSize: Theme.fontSizeTitle
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.svc.stateLabel(folderRow.folder)
                    color: folderRow.stateColor
                    font.family: Theme.monoFont
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Text {
                width: parent.width
                elide: Text.ElideMiddle
                text: `${folderRow.folder.path.replace(Quickshell.env("HOME"), "~")} · ${root.svc.plural(folderRow.folder.globalFiles, "file")} · ${root.svc.bytes(folderRow.folder.globalBytes)}`
                color: Theme.textDisabled
                font.family: Theme.monoFont
                font.pixelSize: Theme.fontSizeSmall
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: folderRow.folder.sharedWith.length > 0 ? `Shared with ${folderRow.folder.sharedWith.join(", ")}`
                                                              : "Not shared with any device"
                color: folderRow.folder.sharedWith.length > 0 ? Theme.textSecondary : Theme.warning
                font.family: Theme.sansFont
                font.pixelSize: Theme.fontSizeSmall
            }

            // Progress while pulling.
            Rectangle {
                visible: folderRow.syncing && folderRow.folder.globalBytes > 0
                width: parent.width
                height: 4
                radius: 2
                color: Theme.track

                Rectangle {
                    width: parent.width * Math.max(0, 1 - folderRow.folder.needBytes / folderRow.folder.globalBytes)
                    height: parent.height
                    radius: 2
                    gradient: AccentGradient {}
                    Behavior on width { NumberAnimation { duration: Theme.durationSlow; easing.type: Easing.OutCubic } }
                }
            }
        }
    }

    // Dot + name; link (LAN · TCP) and how far it is behind, or when it was last seen.
    component DeviceRow: Item {
        id: deviceRow
        property var device
        implicitHeight: 22

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: 2
            width: 8
            height: 8
            radius: 4
            color: deviceRow.device.paused ? Theme.textDisabled
                 : deviceRow.device.connected ? Theme.accent
                 : "transparent"
            border.width: deviceRow.device.connected || deviceRow.device.paused ? 0 : 1.5
            border.color: Theme.textDisabled
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            x: 18
            text: deviceRow.device.name
            color: deviceRow.device.connected ? Theme.textPrimary : Theme.textSecondary
            font.family: Theme.sansFont
            font.pixelSize: Theme.fontSize
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            readonly property var d: deviceRow.device
            text: d.paused ? "Paused"
                : d.connected ? (d.completion >= 0 && d.completion < 100
                                 ? `${d.link} · ${Math.floor(d.completion)}% · ${root.svc.bytes(d.needBytes)} to go`
                                 : d.link)
                : `seen ${root.svc.ago(d.lastSeen)}`
            color: d.connected && d.completion >= 0 && d.completion < 100 ? Theme.accent : Theme.textDisabled
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontSizeSmall
            font.features: { "tnum": 1 }
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
