import "../common"
import QtQuick 2.12
import Quickshell.Services.UPower

Item {
    id: root

    // --- Drawer State ---
    property bool drawerOpen: false

    // --- CONFIG UI ---
    property int segments: 10
    property int barWidth: 260
    property int barHeight: 28
    property int radius: 0
    property int gap: 4

    readonly property var battery: UPower.displayDevice
    property int percent: battery && battery.ready
        ? Math.max(0, Math.min(100, Math.round(battery.percentage * 100)))
        : 0
    readonly property bool charging: !!(battery && battery.ready && battery.state === UPowerDeviceState.Charging)

    // --- UI LAYOUT ---
    width: barWidth
    height: barHeight + 20

    Rectangle {
        id: frame
        anchors.horizontalCenter: parent.horizontalCenter
        width: barWidth
        height: barHeight
        radius: root.radius
        color: "transparent"
        border.color: root.drawerOpen ? Hud.fg : (batteryMouse.containsMouse ? "#c0ffffff" : Hud.dim)
        border.width: root.drawerOpen ? 2 : 1
        Behavior on border.color { ColorAnimation { duration: 150 } }

        // Segments
        Row {
            id: row
            anchors.fill: parent
            anchors.margins: 4
            spacing: gap

            Repeater {
                model: segments
                delegate: Rectangle {
                    width: (row.width - (segments - 1) * gap) / segments
                    height: row.height
                    radius: Math.min(root.radius * 0.6, height/4)
                    color: (index < Math.round(root.percent / (100/segments)))
                           ? (root.percent <= 10 ? "#ff0000" : Hud.fg)
                           : "#30ffffff"
                }
            }
        }
    }

    // Percentage label
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: frame.bottom
        anchors.topMargin: 2
        text: (charging ? "+" : "") + root.percent + "%"
        color: Hud.fg
        font.family: Hud.font
        font.pixelSize: 14
        font.weight: Font.Medium
    }

    // --- Interactive Mouse Area to Toggle Drawer ---
    MouseArea {
        id: batteryMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: root.drawerOpen = !root.drawerOpen
    }

}
