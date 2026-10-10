import QtQuick 2.15

// Square bordered glyph button that lights up on hover.
Rectangle {
    id: btn
    property int boxSize: 30
    property string glyph: ""
    property int glyphSize: 12
    property color hoverBg: Hud.borderPassive
    property color hoverBorder: Hud.fg
    property color idleText: Hud.textMuted
    property color hoverText: Hud.fg
    signal clicked()

    width: boxSize
    height: boxSize
    color: mouse.containsMouse ? hoverBg : "transparent"
    border.width: 1
    border.color: mouse.containsMouse ? hoverBorder : Hud.borderSecondary

    Text {
        anchors.centerIn: parent
        text: btn.glyph
        color: mouse.containsMouse ? btn.hoverText : btn.idleText
        font.family: Hud.font
        font.pixelSize: btn.glyphSize
        font.bold: true
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: btn.clicked()
    }
}
