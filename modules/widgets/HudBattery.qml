import QtQuick 2.12
import Quickshell.Services.UPower

Item {
    id: root

    // --- CONFIG UI ---
    property int segments: 10
    property int barWidth: 260
    property int barHeight: 28
    property int radius: 8
    property int gap: 4
    property color frameColor: "#80ffffff"
    property color emptyColor: "#30ffffff"
    property color textColor: "#ffffff"


    readonly property var battery: UPower.displayDevice
    property int percent: battery && battery.ready
        ? Math.max(0, Math.min(100, Math.round(battery.percentage * 100)))
        : 0
    property bool charging: battery && battery.ready && !UPower.onBattery

    function levelColor(p) {
        if (p <= 10) return "#ff0000"
        return "#ffffff"              
    }

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
        border.color: frameColor
        border.width: 1

        // segmenti
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
                           ? levelColor(root.percent)
                           : emptyColor
                }
            }
        }
    }

    // testo percentuale
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: frame.bottom
        text: (charging ? "+" : "") + root.percent + "%"
        color: textColor
        font.pixelSize: 14
    }
}
