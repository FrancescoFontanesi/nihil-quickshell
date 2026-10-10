import QtQuick 2.15

// Design-system motion: 160ms ease-mechanical (fast start, hard stop, no overshoot).
NumberAnimation {
    duration: Hud.durShort
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Hud.easeMechanical
}
