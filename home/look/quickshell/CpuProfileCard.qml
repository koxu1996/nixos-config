// CpuProfileCard.qml: the CPU profile switch (Saver / Balanced / Performance) plus the
// applied settings line. Data: CpuProfileService. Shown in the battery panel or the CPU/MEM
// panel, depending on the host (Host.cpuProfile).
import QtQuick

Column {
    spacing: 6

    Text {
        text: "CPU profile"
        color: Theme.textSecondary
        font.family: Theme.sansFont
        font.pixelSize: Theme.fontSize
    }

    Rectangle {
        id: profiles
        width: parent.width
        height: Theme.barItemHeight + 8
        radius: Theme.radius
        color: Theme.inset
        border.width: Theme.borderWidth
        border.color: Theme.border

        readonly property string shown: CpuProfileService.pendingProfile || CpuProfileService.profile

        Row {
            id: profileRow
            anchors.fill: parent
            anchors.margins: 4
            spacing: 4

            Repeater {
                model: [
                    { value: "saver", label: "Saver", glyph: "leaf" },
                    { value: "balanced", label: "Balanced", glyph: "scales" },
                    { value: "performance", label: "Performance", glyph: "bolt" },
                ]

                delegate: Rectangle {
                    id: option
                    required property var modelData
                    readonly property bool active: profiles.shown === modelData.value

                    width: (profileRow.width - profileRow.spacing * 2) / 3
                    height: profileRow.height
                    radius: Theme.radiusSmall
                    color: active ? Theme.accentBg : optionMouse.containsMouse ? Theme.hover : "transparent"
                    opacity: CpuProfileService.pendingProfile !== "" && !active ? 0.5 : 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        AppGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            kind: option.modelData.glyph
                            size: 12
                            color: option.active ? Theme.accent : Theme.textSecondary
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: option.modelData.label
                            color: option.active ? Theme.accent : Theme.textSecondary
                            font.family: Theme.sansFont
                            font.pixelSize: Theme.fontSize
                        }
                    }

                    MouseArea {
                        id: optionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: CpuProfileService.pendingProfile === ""
                        onClicked: if (!option.active) CpuProfileService.setProfile(option.modelData.value)
                    }
                }
            }
        }
    }

    Text {
        width: parent.width
        wrapMode: Text.Wrap
        text: CpuProfileService.profileError !== "" ? CpuProfileService.profileError
            : CpuProfileService.pendingProfile !== "" ? "Applying…" : CpuProfileService.profileDetail
        color: CpuProfileService.profileError !== "" ? Theme.error : Theme.textDisabled
        font.family: Theme.monoFont
        font.pixelSize: Theme.fontSizeSmall
    }
}
