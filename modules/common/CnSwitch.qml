import QtQuick 2.15

// Machined switch (cyber-nihilism Switch): 48 × 24 track cut tl + br, 16px thumb,
// explicit ON / OFF word. On = inverted track, thumb travels 24px.
Item {
    id: sw
    property bool checked: false
    property bool busy: false          // state change requested, not confirmed yet
    signal toggled()

    readonly property bool hovered: mouse.containsMouse && enabled

    implicitWidth: 48 + 8 + stateLabel.implicitWidth
    implicitHeight: 24

    CnCut {
        width: 48
        height: 24
        tl: 4
        br: 4
        fill: sw.checked ? Hud.cnInk : Hud.cnGround
        edge: sw.checked || sw.hovered ? Hud.cnInk : Hud.cnBorderActive
        dashed: !sw.enabled || sw.busy
    }

    CnCut {
        width: 16
        height: 16
        y: 4
        x: sw.checked ? 28 : 4
        br: 4
        fill: sw.checked ? Hud.cnGround : (sw.enabled ? Hud.cnInk : Hud.cnTextMuted)
        edge: "transparent"
        Behavior on x { CnAnim {} }
    }

    Text {
        id: stateLabel
        x: 56
        anchors.verticalCenter: parent.verticalCenter
        text: sw.busy ? "LDG" : (sw.checked ? "ON" : "OFF")
        color: sw.checked ? Hud.cnInk : Hud.cnTextSecondary
        font.family: Hud.mono
        font.pixelSize: 11
        font.weight: Font.Medium
        font.letterSpacing: 0.66
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: sw.enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
        onClicked: if (sw.enabled) sw.toggled()
    }
}
