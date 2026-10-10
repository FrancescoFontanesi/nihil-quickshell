import QtQuick 2.15
import QtQuick.Shapes

// Text field (cyber-nihilism Input): micro label, machined box cut bottom-right,
// armed on focus (2px ink edge + armoured top-left corner), error = hatched lead
// strip + inverted ERR chip with the message below.
Item {
    id: field
    property string label
    property alias text: input.text
    property alias echoMode: input.echoMode
    property alias input: input
    property string error: ""
    signal accepted()
    signal escaped()

    readonly property bool armed: input.activeFocus

    implicitHeight: 20 + 32 + (error !== "" ? 6 + 24 : 0)

    Text {
        id: caption
        text: field.label.toUpperCase()
        color: Hud.cnTextMuted
        font.family: Hud.mono
        font.pixelSize: 9
        font.weight: Font.Medium
        font.letterSpacing: 1.0
    }

    Item {
        id: box
        y: 20
        width: parent.width
        height: 32

        CnCut {
            anchors.fill: parent
            br: 8
            fill: Hud.cnGround
            edge: field.armed || field.error !== "" ? Hud.cnInk : (boxMouse.containsMouse ? Hud.cnTextSecondary : Hud.cnBorderActive)
            edgeWidth: field.armed || field.error !== "" ? 2 : 1
        }

        // Armoured top-left corner while armed.
        Shape {
            visible: field.armed
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: Hud.cnInk
                strokeWidth: -1
                startX: 0; startY: 0
                PathLine { x: 12; y: 0 }
                PathLine { x: 0; y: 12 }
                PathLine { x: 0; y: 0 }
            }
        }

        CnHatch {
            visible: field.error !== ""
            x: 2; y: 2
            width: 12
            height: parent.height - 4
        }

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: field.error !== "" ? 22 : 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            color: Hud.cnInk
            selectionColor: Hud.cnInk
            selectedTextColor: Hud.cnGround
            font.family: Hud.mono
            font.pixelSize: 12
            clip: true
            onAccepted: field.accepted()
            Keys.onEscapePressed: field.escaped()
        }

        MouseArea {
            id: boxMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.IBeamCursor
            onPressed: (mouse) => { input.forceActiveFocus(); mouse.accepted = false }
        }
    }

    Row {
        visible: field.error !== ""
        y: box.y + box.height + 6
        spacing: 8
        CnStatus { code: "ERR" }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: field.error
            color: Hud.cnTextSecondary
            font.family: Hud.mono
            font.pixelSize: 9
            font.letterSpacing: 0.54
        }
    }
}
