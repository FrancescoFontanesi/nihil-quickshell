import QtQuick 2.15

// 45° hatching: the design system's mark for critical actions and errors.
Canvas {
    id: hatch
    property color ink: Hud.cnInk
    property int pitch: 4

    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        ctx.strokeStyle = ink
        ctx.lineWidth = 1
        ctx.beginPath()
        for (var x = -height; x < width; x += pitch) {
            ctx.moveTo(x, height)
            ctx.lineTo(x + height, 0)
        }
        ctx.stroke()
    }
}
