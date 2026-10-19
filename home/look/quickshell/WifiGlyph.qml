// WifiGlyph.qml: Wi-Fi icon, three arcs and a dot (17×15 at size 17), 2px round strokes.
// level 1–4 lights the dot plus 0–3 arcs (unlit arcs at 22%); `busy` pulses the arcs in
// sequence; `off` adds a diagonal slash. Dim it by passing a muted colour.
import QtQuick
import QtQuick.Shapes

Item {
    id: glyph

    property int level: 4
    property bool busy: false
    property bool off: false
    property color color: Theme.textPrimary
    property real size: 17

    readonly property real s: size / 17

    implicitWidth: 17 * s
    implicitHeight: 15 * s

    Item {
        width: 17
        height: 15
        scale: glyph.s
        transformOrigin: Item.TopLeft

        Repeater {
            model: 3

            delegate: Shape {
                id: arc
                required property int index
                property real pulse: 0.22

                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                opacity: glyph.busy ? pulse : (glyph.off || index >= glyph.level - 1 ? 0.22 : 1)

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: glyph.color
                    strokeWidth: 2
                    capStyle: ShapePath.RoundCap

                    PathAngleArc {
                        centerX: 8.5
                        centerY: 13.6
                        radiusX: 4.2 + arc.index * 4
                        radiusY: radiusX
                        startAngle: 228
                        sweepAngle: 84
                        moveToStart: true
                    }
                }

                // 1.2 s cycle, each arc 0.15 s after the previous one.
                SequentialAnimation on pulse {
                    running: glyph.busy
                    loops: Animation.Infinite
                    PauseAnimation { duration: arc.index * 150 }
                    NumberAnimation { to: 1; duration: 300; easing.type: Easing.OutQuad }
                    NumberAnimation { to: 0.22; duration: 300; easing.type: Easing.InQuad }
                    PauseAnimation { duration: 600 - arc.index * 150 }
                }
            }
        }

        Rectangle {
            x: 8.5 - 1.5
            y: 13.6 - 1.5
            width: 3
            height: 3
            radius: 1.5
            color: glyph.color
        }

        Shape {
            anchors.fill: parent
            visible: glyph.off
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: glyph.color
                strokeWidth: 2
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M2 1L15 14.5" }
            }
        }
    }
}
