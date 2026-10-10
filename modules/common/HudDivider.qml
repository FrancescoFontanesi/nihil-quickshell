import QtQuick 2.15

// Horizontal rule with a center tick and square end caps.
Item {
    id: divider
    height: 7

    Rectangle {
        anchors.left: parent.left
        anchors.right: tick.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: 1
        color: Hud.dim
    }
    Rectangle {
        anchors.left: tick.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 1
        color: Hud.dim
    }
    Rectangle {
        id: tick
        anchors.centerIn: parent
        width: 1
        height: 7
        color: Hud.fg
    }
    Repeater {
        model: 2
        Rectangle {
            width: 5
            height: 5
            y: 1
            x: index === 0 ? 0 : divider.width - width
            color: Hud.fg
        }
    }
}
