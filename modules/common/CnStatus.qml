import QtQuick 2.15
import QtQuick.Shapes

// State indicator (cyber-nihilism Status): marker shape + 3-letter code, never colour.
// code: NOM ACT IDL LDG OK WRN ERR OFF. ERR is an inverted chip. Only LDG animates
// (three stepped bars), and only while visible.
Item {
    id: st
    property string code: "IDL"
    property color ink: Hud.cnInk
    readonly property bool chip: code === "ERR"
    readonly property color fg: chip ? Hud.cnGround : ink

    implicitWidth: row.implicitWidth + (chip ? 12 : 0)
    implicitHeight: 16

    CnCut {
        anchors.fill: parent
        visible: st.chip
        br: 4
        fill: st.ink
        edge: "transparent"
    }

    Row {
        id: row
        x: st.chip ? 4 : 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Item {
            width: 8
            height: 8
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {   // NOM filled · ACT small square in outline · IDL outline · OFF dashed (approximated) outline
                anchors.fill: parent
                visible: ["NOM", "ACT", "IDL", "OFF"].indexOf(st.code) !== -1
                color: st.code === "NOM" ? st.fg : "transparent"
                border.width: st.code === "NOM" ? 0 : 1
                border.color: st.code === "OFF" ? Hud.cnBorderActive : st.fg
                Rectangle {
                    visible: st.code === "ACT"
                    anchors.centerIn: parent
                    width: 4
                    height: 4
                    color: st.fg
                }
            }

            Row {         // LDG: three bars stepping
                id: bars
                property int step: 0
                visible: st.code === "LDG"
                anchors.bottom: parent.bottom
                spacing: 1
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        width: 2
                        height: index === bars.step ? 8 : 4
                        anchors.bottom: parent.bottom
                        color: st.fg
                    }
                }
                Timer {
                    interval: 300
                    repeat: true
                    running: bars.visible && st.visible
                    onTriggered: bars.step = (bars.step + 1) % 3
                }
            }

            Shape {       // WRN outline triangle · ERR filled triangle · OK check
                anchors.fill: parent
                visible: ["WRN", "ERR", "OK"].indexOf(st.code) !== -1
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: st.fg
                    strokeWidth: 1
                    fillColor: st.code === "ERR" ? st.fg : "transparent"
                    startX: st.code === "OK" ? 0.5 : 4; startY: st.code === "OK" ? 4 : 0.5
                    PathLine { x: st.code === "OK" ? 3 : 7.5; y: st.code === "OK" ? 7 : 7.5 }
                    PathLine { x: st.code === "OK" ? 7.5 : 0.5; y: st.code === "OK" ? 0.5 : 7.5 }
                    PathLine { x: st.code === "OK" ? 7.5 : 4; y: st.code === "OK" ? 0.5 : 0.5 }
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: st.code
            color: st.fg
            font.family: Hud.mono
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 0.66
        }
    }
}
