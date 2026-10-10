import QtQuick 2.15

// Progress ticks (cyber-nihilism Progress): done ticks tall in ink, remaining
// ticks short in grey. value is 0–100; a negative value means unknown (all short).
Item {
    id: ticks
    property real value: 0
    property int count: 32
    implicitHeight: 8

    Repeater {
        model: ticks.count
        Rectangle {
            required property int index
            readonly property bool done: ticks.value >= 0 && index < Math.round(ticks.value / 100 * ticks.count)
            x: Math.round(index * (ticks.width - 2) / Math.max(1, ticks.count - 1))
            anchors.bottom: parent.bottom
            width: 2
            height: done ? 8 : 4
            color: done ? Hud.cnInk : Hud.cnBorderActive
        }
    }
}
