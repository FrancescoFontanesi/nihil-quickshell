import QtQuick 2.15

// Machined switch (cyber-nihilism Switch, compact): 40 × 20 track cut tl + br, 14px thumb,
// explicit ON / OFF word. On = inverted track, thumb travels 20px.
Item {
    id: sw
    property bool checked: false
    property bool busy: false          // state change requested, not confirmed yet
    signal toggled()

    readonly property bool hovered: mouse.containsMouse && enabled

    implicitWidth: 40 + 8 + stateLabel.implicitWidth
    implicitHeight: 20

    CnCut {
        width: 40
        height: 20
        tl: 4
        br: 4
        fill: sw.checked ? Hud.cnInk : Hud.cnGround
        edge: sw.checked || sw.hovered ? Hud.cnInk : Hud.cnBorderActive
        dashed: !sw.enabled || sw.busy
    }

    CnCut {
        width: 14
        height: 14
        y: 3
        x: sw.checked ? 23 : 3
        br: 4
        fill: sw.checked ? Hud.cnGround : (sw.enabled ? Hud.cnInk : Hud.cnTextMuted)
        edge: "transparent"
        Behavior on x { CnAnim {} }
    }

    Text {
        id: stateLabel
        x: 48
        anchors.verticalCenter: parent.verticalCenter
        text: sw.busy ? "LDG" : (sw.checked ? "ON" : "OFF")
        color: sw.checked ? Hud.cnInk : Hud.cnTextSecondary
        font.family: Hud.mono
        font.pixelSize: 9
        font.weight: Font.Medium
        font.letterSpacing: 0.54
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: sw.enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
        onClicked: if (sw.enabled) sw.toggled()
    }
}
