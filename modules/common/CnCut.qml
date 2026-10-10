import QtQuick 2.15
import QtQuick.Shapes

// Machined 45° profile (cyber-nihilism `.cn-cut`): one polygon with per-corner
// chamfers, an edge stroke kept inside the item and an optional fill.
Shape {
    id: cut
    property real tl: 0
    property real tr: 0
    property real br: 0
    property real bl: 0
    property color fill: "transparent"
    property color edge: Hud.cnBorderActive
    property real edgeWidth: 1
    property bool dashed: false

    readonly property real _s: edge.a > 0 ? edgeWidth / 2 : 0

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: cut.fill
        strokeColor: cut.edge
        strokeWidth: cut.edge.a > 0 ? cut.edgeWidth : -1
        strokeStyle: cut.dashed ? ShapePath.DashLine : ShapePath.SolidLine
        dashPattern: [4 / cut.edgeWidth, 4 / cut.edgeWidth]
        joinStyle: ShapePath.MiterJoin
        capStyle: ShapePath.FlatCap

        startX: cut._s + cut.tl; startY: cut._s
        PathLine { x: cut.width - cut._s - cut.tr; y: cut._s }
        PathLine { x: cut.width - cut._s; y: cut._s + cut.tr }
        PathLine { x: cut.width - cut._s; y: cut.height - cut._s - cut.br }
        PathLine { x: cut.width - cut._s - cut.br; y: cut.height - cut._s }
        PathLine { x: cut._s + cut.bl; y: cut.height - cut._s }
        PathLine { x: cut._s; y: cut.height - cut._s - cut.bl }
        PathLine { x: cut._s; y: cut._s + cut.tl }
        PathLine { x: cut._s + cut.tl; y: cut._s }
    }
}
