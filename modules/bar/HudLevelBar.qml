import "../common"
import QtQuick 2.12

Item {
    id: root

    property int s: 10
    property int rectW: 300
    property int rectH: 80
    property int topMargin: 24

    property url iconSource: ""
    property int iconSize: 24
    property int iconTopMargin: 8
    property int percent: 0
    property color fillColor: "#ffffff"

    width:  rectW + 2*s
    height: rectH + topMargin + s + (iconSource==""?0:iconSize+iconTopMargin)

    HudCornerFrame {
        x: root.s
        y: root.topMargin
        width: root.rectW
        height: root.rectH
        nodeSize: root.s
        lineWidth: 2
    }

    Rectangle {
        id: frame
        x: root.s + s + 4
        y: root.topMargin + s
        width:  rectW - 2 * (s + 4)
        height: Math.max(rectH - 2 * s, 8)
        radius: 2
        color: "transparent"
        border.width: 1

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.margins: 2
            height: Math.max(parent.height - 4, 4)
            width: Math.max(0, Math.round((parent.width - 4) * root.percent / 100))
            radius: 1
            color: root.fillColor
            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
    }

    Image {
        visible: iconSource !== ""
        source: iconSource
        width: iconSize; height: iconSize
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: frame.bottom
        anchors.topMargin: root.iconTopMargin
        fillMode: Image.PreserveAspectFit
    }
}
