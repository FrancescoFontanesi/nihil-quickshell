import QtQuick 2.15

// Flyout drawer chassis, same plate as the overlay HUD panels: animated height,
// micro-label + title header, optional status strip (code + text), close button
// and corner frame. Children go inside the panel; anchor them below `header`.
Item {
    id: drawer
    property bool open: false
    property string code          // micro-label above the title, e.g. "CAL · 2026-10-10"
    property string title
    property string statusCode    // NOM ACT IDL LDG OK WRN ERR OFF; empty hides the strip
    property string statusText
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

    Behavior on height { CnAnim { duration: Hud.durMedium } }

    Rectangle {
        id: panel
        anchors.fill: parent
        color: "#d8000000"
        border.width: 1
        border.color: Hud.borderPassive

        // Swallow clicks so they don't reach the window's close-on-click area.
        MouseArea { anchors.fill: parent }

        Item {
            id: headerItem
            x: 16
            y: 14
            width: parent.width - 32
            height: drawer.statusCode !== "" ? 63 : 37

            Text {
                text: drawer.code
                color: Hud.cnTextMuted
                font.family: Hud.mono
                font.pixelSize: 9
                font.letterSpacing: 1.0
            }

            Text {
                id: titleText
                y: 12
                width: parent.width - 30
                text: drawer.title
                color: Hud.cnInk
                font.family: Hud.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
                elide: Text.ElideRight
            }

            CnButton {
                anchors.right: parent.right
                anchors.verticalCenter: titleText.verticalCenter
                width: 22
                height: 22
                cut: 4
                text: "✕"
                textSize: 11
                onClicked: drawer.closeRequested()
            }

            Row {
                visible: drawer.statusCode !== ""
                y: 36
                spacing: 8
                CnStatus { code: drawer.statusCode }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: headerItem.width - 60
                    text: drawer.statusText
                    color: Hud.cnTextSecondary
                    font.family: Hud.mono
                    font.pixelSize: 9
                    font.letterSpacing: 0.54
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Hud.cnBorderPassive
            }
        }
    }

    HudCornerFrame {
        anchors.fill: parent
        z: 20
        visible: drawer.height > 20
    }
}
