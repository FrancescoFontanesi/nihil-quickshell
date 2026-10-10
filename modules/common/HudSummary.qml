import QtQuick 2.15

// Drawer summary block: three centered lines on the left (headline, big value,
// caption), label/value rows on the right, a ticked vertical rule between them.
Item {
    id: summary
    property string headline
    property string value
    property color valueColor: Hud.fg
    property string caption
    property bool captionBold: false
    property var rows: []   // [{ label, value }]
    height: 104

    Item {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: divider.left
        anchors.rightMargin: 12

        Column {
            anchors.centerIn: parent
            width: parent.width - 10
            spacing: 2

            Text {
                width: parent.width
                text: summary.headline
                color: Hud.textPrimary
                font.family: Hud.font
                font.pixelSize: 12
                font.bold: true
                font.letterSpacing: 0.5
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: summary.value
                color: summary.valueColor
                font.family: Hud.font
                font.pixelSize: 24
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                width: parent.width
                text: summary.caption
                color: Hud.textSecondary
                font.family: Hud.font
                font.pixelSize: 12
                font.bold: summary.captionBold
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }

    Item {
        id: divider
        anchors.right: details.left
        anchors.rightMargin: 23
        anchors.top: parent.top
        anchors.topMargin: 6
        width: 7
        height: parent.height - 12

        Rectangle {
            anchors.centerIn: parent
            width: 1
            height: parent.height - 10
            color: Hud.dim
        }
        Repeater {
            model: 2
            Rectangle {
                width: 5
                height: 5
                x: 1
                y: index === 0 ? 0 : divider.height - height
                color: Hud.fg
            }
        }
    }

    Column {
        id: details
        anchors.right: parent.right
        anchors.rightMargin: 36
        anchors.verticalCenter: parent.verticalCenter
        width: 136
        spacing: 7

        Repeater {
            model: summary.rows
            StatRow {
                required property var modelData
                width: details.width
                label: modelData.label
                value: modelData.value
                labelColor: Hud.textMuted
            }
        }
    }
}
