import QtQuick 2.15

// Drawer summary: key, live readout and caption on the left (mono, the readout
// style for values that update), label/value rows on the right, a 1px rule between.
Item {
    id: summary
    property string headline
    property string value
    property color valueColor: Hud.cnInk
    property string caption
    property var rows: []   // [{ label, value }]
    height: 84

    Column {
        anchors.left: parent.left
        anchors.right: divider.left
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Text {
            width: parent.width
            text: String(summary.headline).toUpperCase()
            color: Hud.cnTextMuted
            font.family: Hud.mono
            font.pixelSize: 9
            font.letterSpacing: 0.9
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: summary.value
            color: summary.valueColor
            font.family: Hud.mono
            font.pixelSize: 24
            font.weight: Font.Light
        }
        Text {
            width: parent.width
            text: String(summary.caption).toUpperCase()
            color: Hud.cnTextSecondary
            font.family: Hud.mono
            font.pixelSize: 9
            font.letterSpacing: 0.54
            elide: Text.ElideRight
        }
    }

    Rectangle {
        id: divider
        anchors.right: details.left
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: parent.height - 16
        color: Hud.cnBorderPassive
    }

    Column {
        id: details
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 150
        spacing: 4

        Repeater {
            model: summary.rows
            StatRow {
                required property var modelData
                width: details.width
                label: modelData.label
                value: modelData.value
            }
        }
    }
}
