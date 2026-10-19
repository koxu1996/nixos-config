// GlowSlider.qml: horizontal slider for the Glow popup.
// Either a full-gradient track (`trackGradient`) or the theme's lime fill over a dark track.
// Optional mark (e.g. 6500 K "neutral") and labels under the track.
import QtQuick

Item {
    id: slider

    property real from: 0
    property real to: 100
    property real step: 1
    property real value: 0
    property Gradient trackGradient: null
    property string leftLabel: ""
    property string rightLabel: ""
    property real markValue: NaN
    property string markLabel: ""

    signal moved(real value)

    readonly property real handleSize: 16
    readonly property real usable: width - handleSize
    readonly property real position: (Math.max(from, Math.min(to, value)) - from) / (to - from)
    function xFor(v) { return handleSize / 2 + usable * (v - from) / (to - from); }

    implicitHeight: 22 + (labels.visible ? labels.height + 4 : 0)

    Item {
        id: trackArea
        width: parent.width
        height: 22

        Rectangle {
            id: track
            x: slider.handleSize / 2
            width: slider.usable
            height: 6
            radius: 3
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.track
            gradient: slider.trackGradient

            // Lime fill (only without a gradient track).
            Rectangle {
                visible: !slider.trackGradient && slider.position > 0
                width: Math.max(height, track.width * slider.position)
                height: parent.height
                radius: parent.radius
                gradient: AccentGradient {}
            }
        }

        // Mark (e.g. neutral 6500 K).
        Rectangle {
            visible: !isNaN(slider.markValue)
            x: slider.xFor(slider.markValue) - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: 12
            radius: 1
            color: Theme.textDisabled
        }

        Rectangle {
            x: slider.usable * slider.position
            anchors.verticalCenter: parent.verticalCenter
            width: slider.handleSize
            height: slider.handleSize
            radius: width / 2
            color: Theme.textPrimary
            border.width: 3
            border.color: Theme.inset
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            function apply(mx) {
                const t = Math.max(0, Math.min(1, (mx - slider.handleSize / 2) / slider.usable));
                const raw = slider.from + t * (slider.to - slider.from);
                slider.moved(Math.round(raw / slider.step) * slider.step);
            }
            onPressed: mouse => apply(mouse.x)
            onPositionChanged: mouse => { if (pressed) apply(mouse.x); }
            onWheel: wheel => slider.moved(Math.max(slider.from, Math.min(slider.to,
                slider.value + (wheel.angleDelta.y > 0 ? slider.step : -slider.step))))
        }
    }

    // Labels under the track.
    Item {
        id: labels
        visible: slider.leftLabel !== "" || slider.rightLabel !== "" || slider.markLabel !== ""
        y: trackArea.height + 4
        width: parent.width
        height: leftText.implicitHeight

        Text {
            id: leftText
            text: slider.leftLabel
            color: Theme.textDisabled
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontSizeSmall
        }

        Text {
            visible: !isNaN(slider.markValue) && slider.markLabel !== ""
            x: Math.max(leftText.width + 8, Math.min(parent.width - width - 40, slider.xFor(slider.markValue) - width / 2))
            text: slider.markLabel
            color: Theme.textDisabled
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontSizeSmall
        }

        Text {
            anchors.right: parent.right
            text: slider.rightLabel
            color: Theme.textDisabled
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
