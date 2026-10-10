import QtQuick 2.15

// Micro-label key on the left, mono value on the right.
Item {
    id: row
    property string label
    property var value
    property color valueColor: Hud.cnInk
    height: 18

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: String(row.label).toUpperCase()
        color: Hud.cnTextMuted
        font.family: Hud.mono
        font.pixelSize: 9
        font.letterSpacing: 0.9
    }
    Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: row.value
        color: row.valueColor
        font.family: Hud.mono
        font.pixelSize: 11
        font.weight: Font.Medium
    }
}
