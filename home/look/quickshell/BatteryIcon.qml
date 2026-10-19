// BatteryIcon.qml: battery outline (55 % opacity) with a fill proportional to `level`
// and a bolt cut out of it while charging. Sizes: 22×12 (chip), 46×24 (panel header).
import QtQuick
import QtQuick.Shapes

Item {
    id: icon

    property real level: 0          // 0–1
    property bool charging: false
    property color color: Theme.textPrimary
    property color cutoutColor: Theme.base // background behind the icon (for the bolt)

    implicitWidth: 22
    implicitHeight: 12

    readonly property real nub: Math.max(2, Math.round(width * 0.08))
    readonly property real stroke: Math.max(1, Math.round(height / 12))
    readonly property real inset: stroke + Math.max(1, Math.round(height / 12))

    // Body outline.
    Rectangle {
        id: body
        width: parent.width - icon.nub - 1
        height: parent.height
        radius: Math.round(height * 0.25)
        color: "transparent"
        border.width: icon.stroke
        border.color: icon.color
        opacity: 0.55
    }

    // Terminal nub.
    Rectangle {
        x: body.width + 1
        anchors.verticalCenter: parent.verticalCenter
        width: icon.nub
        height: Math.round(parent.height * 0.4)
        radius: 1
        color: icon.color
        opacity: 0.55
    }

    // Level fill.
    Rectangle {
        id: fill
        x: icon.inset
        y: icon.inset
        width: Math.max(0, (body.width - icon.inset * 2) * Math.max(0, Math.min(1, icon.level)))
        height: body.height - icon.inset * 2
        radius: Math.max(1, body.radius - icon.inset)
        color: icon.color
    }

    // Bolt cut-out while charging (drawn in the background colour over the fill).
    Shape {
        visible: icon.charging
        anchors.centerIn: body
        width: 24
        height: 24
        scale: (body.height + 2) / 24
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: icon.cutoutColor
            strokeColor: icon.cutoutColor
            strokeWidth: 2.5
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: Glyphs.paths.bolt }
        }
        ShapePath {
            fillColor: icon.color
            strokeColor: "transparent"
            PathSvg { path: Glyphs.paths.bolt }
        }
    }
}
