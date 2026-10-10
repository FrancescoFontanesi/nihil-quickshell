import "../common"
import QtQuick 2.12
import Quickshell

Item {
    id: root

    // --- Drawer State ---
    property bool drawerOpen: false

    // --- Geometry / style (One-Shot Unified Frame) ---
    property int s: 6
    property int rectW: 348
    property int rectH: 40
    property int topMargin: 20

    // Unified dimensions: root itself defines the clock HUD bounds
    width: rectW
    height: rectH
    anchors.topMargin: topMargin

    // --- Time & Date (locale) ---
    SystemClock { id: clock; precision: SystemClock.Seconds }
    property string timeText: Qt.formatTime(clock.date, "HH:mm:ss")
    property string dateText: Qt.locale("en_US").toString(clock.date, "ddd dd MMM").toUpperCase()

    // --- Background Surface (Unified with root dimensions) ---
    Rectangle {
        id: bgRect
        z: 0
        anchors.fill: parent
        color: root.drawerOpen ? '#d8050607' : (clockMouse.containsMouse ? '#c00a0c0e' : '#a8050607')
        border.width: root.drawerOpen ? 2 : 1
        border.color: root.drawerOpen ? Hud.fg : (clockMouse.containsMouse ? '#a0ffffff' : '#20ffffff')

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        Row {
            spacing: 12
            anchors.centerIn: parent

            Text {
                text: root.timeText
                font.family: Hud.font
                font.pixelSize: 20
                font.letterSpacing: 1.2
                color: Hud.fg
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                text: "//"
                font.family: Hud.font
                font.pixelSize: 20
                font.weight: Font.DemiBold
                color: '#a4ffffff'
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                text: root.dateText
                font.family: Hud.font
                font.pixelSize: 20
                font.letterSpacing: 1.2
                color: Hud.fg
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // --- Interactive Mouse Area to Toggle Drawer ---
    MouseArea {
        id: clockMouse
        z: 3
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: {
            root.drawerOpen = !root.drawerOpen
        }
    }

    HudCornerFrame {
        anchors.fill: parent
        z: 1
        nodeSize: root.s
    }

}
