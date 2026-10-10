import QtQuick 2.15

// Four square corner nodes joined by an outline through their centers.
// Size it like the rect to decorate (anchors.fill or x/y/width/height).
Item {
    id: frame
    property int nodeSize: 6
    property color nodeColor: Hud.fg
    property color lineColor: Hud.dim
    property int lineWidth: 1

    onWidthChanged: lines.requestPaint()
    onHeightChanged: lines.requestPaint()
    onLineColorChanged: lines.requestPaint()
    onLineWidthChanged: lines.requestPaint()
    onNodeSizeChanged: lines.requestPaint()

    Canvas {
        id: lines
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d"), h = frame.nodeSize / 2
            ctx.clearRect(0, 0, width, height)
            ctx.lineWidth = frame.lineWidth
            ctx.strokeStyle = frame.lineColor
            ctx.strokeRect(h, h, width - 2 * h, height - 2 * h)
        }
    }

    Repeater {
        model: 4
        Rectangle {
            width: frame.nodeSize
            height: frame.nodeSize
            color: frame.nodeColor
            x: index % 2 ? frame.width - width : 0
            y: index >= 2 ? frame.height - height : 0
        }
    }
}
