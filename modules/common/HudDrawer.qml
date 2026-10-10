import QtQuick 2.15

// Flyout drawer chassis: animated height, panel background, title + close button
// header and corner frame. Children go inside the panel; anchor them below `header`.
Item {
    id: drawer
    property bool open: false
    property string title
    property int titleSize: 12
    property int drawerWidth: 440
    property int drawerHeight: 430
    property int drawerMargin: 8
    readonly property alias header: headerItem
    default property alias content: panel.data
    signal closeRequested()

    width: drawerWidth
    height: open ? drawerHeight : 0
    visible: height > 0
    clip: true

    Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    Rectangle {
        id: panel
        anchors.fill: parent
        color: Hud.panelBg

        // Swallow clicks so they don't reach the window's close-on-click area.
        MouseArea { anchors.fill: parent }

        Item {
            id: headerItem
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            height: 26

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 42
                text: drawer.title
                color: Hud.textPrimary
                font.family: Hud.font
                font.pixelSize: drawer.titleSize
                font.bold: true
                font.letterSpacing: 1
                elide: Text.ElideRight
            }

            HudButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                boxSize: 26
                glyph: "✕"
                glyphSize: 18
                onClicked: drawer.closeRequested()
            }
        }
    }

    HudCornerFrame {
        anchors.fill: parent
        z: 20
        visible: drawer.height > 20
    }
}
