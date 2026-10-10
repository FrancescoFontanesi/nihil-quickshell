import QtQuick 2.15

// Four corner nodes that fly between a collapsed 2x2 cluster and the corners of
// openRect with a staggered OutBack animation, joined by an outline through their centers.
Item {
    id: frame
    property bool open: false
    property bool animate: true                // gates the node Behaviors
    property rect openRect: Qt.rect(0, 0, 0, 0)
    property point closedPos: Qt.point(0, 0)   // top-left of the collapsed cluster
    property int nodeSize: 8
    property int gap: 12
    property real nodeRadius: 0
    property int staggerStep: 60
    property int animDur: 360
    property real overshoot: 0.8
    property int lineWidth: 1
    property color nodeColor: Hud.fg
    property color lineColor: Hud.dim

    Canvas {
        id: lines
        anchors.fill: parent
        onPaint: {
            var a = nodes.itemAt(0), b = nodes.itemAt(1), c = nodes.itemAt(3), d = nodes.itemAt(2)
            if (!a || !b || !c || !d) return
            var ctx = getContext("2d"), h = frame.nodeSize / 2
            ctx.clearRect(0, 0, width, height)
            ctx.lineWidth = frame.lineWidth
            ctx.lineJoin = "round"
            ctx.lineCap = "round"
            ctx.strokeStyle = frame.lineColor
            ctx.beginPath()
            ctx.moveTo(a.x + h, a.y + h)
            ctx.lineTo(b.x + h, b.y + h)
            ctx.lineTo(c.x + h, c.y + h)
            ctx.lineTo(d.x + h, d.y + h)
            ctx.closePath()
            ctx.stroke()
        }
    }

    Repeater {
        id: nodes
        model: 4
        Rectangle {
            readonly property bool isRight: index % 2 === 1
            readonly property bool isBottom: index >= 2
            readonly property int stagIndex: frame.open ? index : 3 - index

            width: frame.nodeSize
            height: frame.nodeSize
            radius: frame.nodeRadius
            color: frame.nodeColor
            x: frame.open ? frame.openRect.x + (isRight ? frame.openRect.width - width : 0)
                          : frame.closedPos.x + (isRight ? width + frame.gap : 0)
            y: frame.open ? frame.openRect.y + (isBottom ? frame.openRect.height - height : 0)
                          : frame.closedPos.y + (isBottom ? height + frame.gap : 0)

            Behavior on x {
                enabled: frame.animate
                SequentialAnimation {
                    PauseAnimation { duration: stagIndex * frame.staggerStep }
                    NumberAnimation { duration: frame.animDur; easing.type: Easing.OutBack; easing.overshoot: frame.overshoot }
                }
            }
            Behavior on y {
                enabled: frame.animate
                SequentialAnimation {
                    PauseAnimation { duration: stagIndex * frame.staggerStep }
                    NumberAnimation { duration: frame.animDur; easing.type: Easing.OutBack; easing.overshoot: frame.overshoot }
                }
            }

            onXChanged: lines.requestPaint()
            onYChanged: lines.requestPaint()
        }
    }
}
