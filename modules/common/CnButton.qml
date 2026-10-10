import QtQuick 2.15
import QtQuick.Shapes

// Machined button (cyber-nihilism Button): one 45° cut bottom-right. Hover drops the
// cut's complement back into it; press moves 1px and inverts.
// variant: "secondary" (outline), "primary" (inverted slab), "critical" (2px edge + hatched lead).
Item {
    id: btn
    property string text
    property string variant: "secondary"
    property int cut: 8
    property int textSize: 14
    signal clicked()

    readonly property bool hovered: mouse.containsMouse && enabled
    readonly property bool pressed: mouse.pressed && enabled
    readonly property bool inverted: enabled && (variant === "primary" ? !pressed : pressed)
    readonly property color ink: inverted ? Hud.cnGround : (enabled ? Hud.cnInk : Hud.cnTextMuted)

    implicitHeight: 32
    implicitWidth: label.implicitWidth + 32 + (variant === "critical" ? 12 : 0)

    transform: Translate { y: btn.pressed ? 1 : 0 }

    CnCut {
        anchors.fill: parent
        br: btn.cut
        fill: btn.inverted ? Hud.cnInk : Hud.cnGround
        edge: !btn.enabled ? Hud.cnBorderActive
              : (btn.variant !== "secondary" || btn.hovered ? Hud.cnInk : Hud.cnBorderActive)
        edgeWidth: btn.variant === "critical" ? 2 : 1
        dashed: !btn.enabled
    }

    CnHatch {
        visible: btn.variant === "critical"
        x: 2; y: 2
        width: 8
        height: parent.height - 4
        ink: btn.ink
    }

    // Complement: the piece the cut removed, gap c/4, legs c − c/4·√2.
    Shape {
        readonly property real leg: btn.cut * (1 - Math.SQRT2 / 4)
        visible: btn.hovered && !btn.pressed && btn.variant !== "primary"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Hud.cnInk
            strokeWidth: -1
            startX: btn.width; startY: btn.height
            PathLine { x: btn.width - parent.leg; y: btn.height }
            PathLine { x: btn.width; y: btn.height - parent.leg }
            PathLine { x: btn.width; y: btn.height }
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: btn.variant === "critical" ? 6 : 0
        anchors.verticalCenterOffset: 1
        text: btn.text.toUpperCase()
        color: btn.ink
        font.family: Hud.font
        font.pixelSize: btn.textSize
        font.weight: Font.DemiBold
        font.letterSpacing: btn.textSize * 0.06
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: btn.enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
        onClicked: if (btn.enabled) btn.clicked()
    }
}
