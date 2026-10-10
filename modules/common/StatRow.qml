import QtQuick 2.15

// Label on the left, bold value on the right.
Item {
    id: row
    property string label
    property var value
    property color labelColor: Hud.textSecondary
    property color valueColor: Hud.fg
    property int labelSize: 11
    property int valueSize: 15
    height: 21

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: row.label
        color: row.labelColor
        font.family: Hud.font
        font.pixelSize: row.labelSize
    }
    Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: row.value
        color: row.valueColor
        font.family: Hud.font
        font.pixelSize: row.valueSize
        font.bold: true
    }
}
