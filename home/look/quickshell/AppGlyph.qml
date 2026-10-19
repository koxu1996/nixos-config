// AppGlyph.qml: one of the shared Glyphs, stroked and scaled to `size`.
import QtQuick
import QtQuick.Shapes

Item {
    id: glyph

    property string kind
    property color color
    property int size: 14

    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 24
        height: 24
        scale: glyph.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: glyph.color
            strokeWidth: 2
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: Glyphs.paths[glyph.kind] ?? "" }
        }
    }
}
