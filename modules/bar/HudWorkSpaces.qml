import "../common"
import QtQuick 2.12
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    // --- Configuration ---
    readonly property int workspaceCount: 10
    readonly property int perRow: 5

    // Dynamic resolution scaling based on parent panel width (reference: 2160x1440)
    readonly property real scaleRatio: parent && parent.width > 0 ? (parent.width / 2160.0) : 1.0

    // Geometry in true screen pixels (no transform scale artifacts)
    property int cellWidth: Math.round(32 * scaleRatio)
    property int cellHeight: Math.round(32 * scaleRatio)
    property int cellSpacing: Math.round(12 * scaleRatio)
    property int indicatorPadding: Math.round(2 * scaleRatio)
    property int indicatorNodeSize: Math.max(4, Math.round(5 * scaleRatio))
    property int groupDistance: Math.round(748 * scaleRatio)

    readonly property int groupWidth: perRow * cellWidth + (perRow - 1) * cellSpacing

    width: groupDistance + groupWidth + indicatorPadding * 2
    height: cellHeight + indicatorPadding * 2
    implicitWidth: width
    implicitHeight: height

    // --- Style (shared by several cells) ---
    readonly property color emptyColor: '#6e000000'
    readonly property color occupiedColor: '#c5ffffff'

    // --- Reactive State Tracking ---
    readonly property int activeWorkspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    readonly property int activeIdx: activeWorkspaceId >= 1 && activeWorkspaceId <= workspaceCount ? (activeWorkspaceId - 1) : -1

    function horizontalPos(idx) {
        var col = idx % perRow
        var base = indicatorPadding + col * (cellWidth + cellSpacing)
        if (idx >= perRow)
            base += groupDistance
        return base
    }

    // Monitor-agnostic persistent rules, applied once at load so focusing another monitor does not re-pin them
    Component.onCompleted: {
        var cmds = []
        for (var i = 1; i <= root.workspaceCount; ++i)
            cmds.push("keyword workspace " + i + ",persistent:true")
        Quickshell.execDetached(["hyprctl", "--batch", cmds.join(" ; ")])
    }

    // --- Indicator Frame (Slides to Active Workspace) ---
    HudCornerFrame {
        id: indicator
        z: 10
        visible: root.activeIdx >= 0
        width: root.cellWidth + root.indicatorPadding * 2
        height: root.cellHeight + root.indicatorPadding * 2
        x: root.activeIdx >= 0 ? (root.horizontalPos(root.activeIdx) - root.indicatorPadding) : 0
        y: 0
        nodeSize: root.indicatorNodeSize
        nodeColor: "#ffffff"
        lineColor: "#80ffffff"

        Behavior on x {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
    }

    // --- Workspace Cells ---
    Repeater {
        model: root.workspaceCount

        delegate: Item {
            readonly property int workspaceId: index + 1
            readonly property var ws: Hyprland.workspaces.values.find(w => w.id === workspaceId) ?? null
            readonly property bool isOccupied: !!ws && ws.toplevels.values.length > 0
            readonly property bool isActive: root.activeWorkspaceId === workspaceId

            width: root.cellWidth
            height: root.cellHeight
            x: root.horizontalPos(index)
            y: root.indicatorPadding

            Rectangle {
                anchors.fill: parent
                radius: 2
                color: isOccupied ? root.occupiedColor : root.emptyColor
                border.color: isOccupied ? root.emptyColor : root.occupiedColor
                border.width: isActive ? 4 : 2
                antialiasing: true
                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutCubic } }
            }

            Text {
                anchors.centerIn: parent
                text: String(workspaceId)
                color: isOccupied ? "#000000" : "#ffffff"
                font.pixelSize: Math.round(root.cellHeight * 0.45)
                font.weight: Font.DemiBold
                font.family: Hud.font
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                renderType: Text.QtRendering
                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("workspace " + workspaceId)
            }
        }
    }
}
