// MonthCalendar.qml: read-only month view for the clock popup (Monday-first, 6×7 grid).
import QtQuick

Rectangle {
    id: calendar

    property int viewYear: ClockService.now.getFullYear()
    property int viewMonth: ClockService.now.getMonth()
    readonly property bool showingCurrent:
        viewYear === ClockService.now.getFullYear() && viewMonth === ClockService.now.getMonth()

    function step(delta) {
        const d = new Date(viewYear, viewMonth + delta, 1);
        viewYear = d.getFullYear();
        viewMonth = d.getMonth();
    }
    function goToday() {
        viewYear = ClockService.now.getFullYear();
        viewMonth = ClockService.now.getMonth();
    }

    readonly property real cellWidth: grid.width / 7

    implicitHeight: content.implicitHeight + 24
    radius: Theme.radius
    color: Theme.inset
    border.width: Theme.borderWidth
    border.color: Theme.borderSubtle

    Column {
        id: content
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 10

        // ---- Header: month + year, Today pill, chevrons ----
        Item {
            width: parent.width
            implicitHeight: 26

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: `${ClockService.monthNames[calendar.viewMonth]} ${calendar.viewYear}`
                color: Theme.textPrimary
                font.family: Theme.sansFont
                font.pixelSize: Theme.fontSizeTitle
                font.weight: Font.Medium
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Rectangle {
                    visible: !calendar.showingCurrent
                    anchors.verticalCenter: parent.verticalCenter
                    width: todayText.implicitWidth + 16
                    height: 24
                    radius: Theme.radiusSmall
                    color: Theme.accentBg

                    Text {
                        id: todayText
                        anchors.centerIn: parent
                        text: "Today"
                        color: Theme.accent
                        font.family: Theme.sansFont
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calendar.goToday()
                    }
                }

                ChevronButton { kind: "chevronLeft"; onClicked: calendar.step(-1) }
                ChevronButton { kind: "chevronRight"; onClicked: calendar.step(1) }
            }
        }

        // ---- Weekday row ----
        Row {
            Repeater {
                model: ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
                delegate: Text {
                    required property string modelData
                    width: calendar.cellWidth
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.textDisabled
                    font.family: Theme.monoFont
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        // ---- Day grid: always 42 cells ----
        Grid {
            id: grid
            width: parent.width
            columns: 7
            rowSpacing: 4

            Repeater {
                model: ClockService.monthGrid(calendar.viewYear, calendar.viewMonth)

                delegate: Item {
                    id: cell
                    required property var modelData
                    width: calendar.cellWidth
                    height: 30

                    Rectangle {
                        anchors.centerIn: parent
                        width: 30
                        height: 30
                        radius: width / 2
                        visible: cell.modelData.today && cell.modelData.inMonth
                        color: Theme.accent
                    }

                    Text {
                        anchors.centerIn: parent
                        readonly property bool isToday: cell.modelData.today && cell.modelData.inMonth
                        text: cell.modelData.day
                        color: isToday ? Theme.textOnAccent
                             : !cell.modelData.inMonth ? Theme.textFaint
                             : cell.modelData.weekend ? Theme.textSecondary
                             : Theme.textPrimary
                        font.family: Theme.monoFont
                        font.pixelSize: Theme.fontSizeTitle
                        font.weight: isToday ? Font.DemiBold : Font.Normal
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }
    }

    component ChevronButton: Rectangle {
        id: chevron
        property string kind
        signal clicked()

        width: 26
        height: 26
        radius: Theme.radiusSmall
        color: chevronMouse.containsMouse ? Theme.raised : "transparent"

        AppGlyph {
            anchors.centerIn: parent
            kind: chevron.kind
            color: Theme.textSecondary
            size: Theme.iconSize
        }

        MouseArea {
            id: chevronMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chevron.clicked()
        }
    }
}
