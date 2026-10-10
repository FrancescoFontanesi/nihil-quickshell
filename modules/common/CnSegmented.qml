import QtQuick 2.15

// Segmented control (cyber-nihilism Tabs, variant segmented): cells joined in one
// machined group cut bottom-right; the selected cell is inverted.
// items: [{ key, label, count? }]
Item {
    id: seg
    property var items: []
    property string value
    signal selected(string key)

    implicitHeight: 26

    CnCut {
        anchors.fill: parent
        br: 8
        fill: Hud.cnGround
        edge: Hud.cnBorderActive
    }

    Row {
        anchors.fill: parent
        anchors.margins: 1

        Repeater {
            model: seg.items

            Item {
                id: cell
                required property var modelData
                required property int index
                readonly property bool current: modelData.key === seg.value
                readonly property bool last: index === seg.items.length - 1

                width: (seg.width - 2) / Math.max(1, seg.items.length)
                height: parent.height

                CnCut {
                    anchors.fill: parent
                    visible: cell.current
                    br: cell.last ? 7 : 0
                    fill: Hud.cnInk
                    edge: "transparent"
                }

                Rectangle {
                    visible: cell.index > 0
                    width: 1
                    height: parent.height
                    color: Hud.cnBorderPassive
                }

                Text {
                    anchors.centerIn: parent
                    text: cell.modelData.label.toUpperCase()
                          + (cell.modelData.count !== undefined ? "  " + String(cell.modelData.count).padStart(2, "0") : "")
                    color: cell.current ? Hud.cnGround : (cellMouse.containsMouse ? Hud.cnInk : Hud.cnTextSecondary)
                    font.family: Hud.mono
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    font.letterSpacing: 0.54
                    Behavior on color { ColorAnimation { duration: Hud.durMicro } }
                }

                MouseArea {
                    id: cellMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: seg.selected(cell.modelData.key)
                }
            }
        }
    }
}
