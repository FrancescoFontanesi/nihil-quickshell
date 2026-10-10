import "../common"
import QtQuick 2.12
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    // --- Configuration ---
    property int workspaceCount: 10
    property int perRow: 5

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

    // --- Style (Original Preserved) ---
    property color emptyColor: '#6e000000'
    property color emptyTextColor: "#ffffff"
    property color occupiedColor: '#c5ffffff'
    property color occupiedTextColor: "#000000"
    property int workspaceBorderWidth: 2
    property int workspaceActiveBorderWidth: 4
    property real workspaceCornerRadius: 2

    // Indicator Style
    property bool showIndicator: true
    property int indicatorAnimDuration: 200
    property color indicatorNodeColor: "#ffffff"
    property color indicatorOutlineColor: "#80ffffff"

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

    function ensurePersistence() {
        var mon = (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) ? Hyprland.focusedMonitor.name : "eDP-1"
        var cmds = []
        for (var i = 1; i <= root.workspaceCount; ++i)
            cmds.push("keyword workspace " + i + ",monitor:" + mon + ",persistent:true")
        Quickshell.execDetached(["hyprctl", "--batch", cmds.join(" ; ")])
    }

    Component.onCompleted: ensurePersistence()

    Connections {
        target: Hyprland

        function onFocusedMonitorChanged() {
            root.ensurePersistence()
        }
    }

    // --- Indicator Frame (Slides to Active Workspace) ---
    HudCornerFrame {
        id: indicator
        z: 10
        visible: root.showIndicator && root.activeIdx >= 0
        width: root.cellWidth + root.indicatorPadding * 2
        height: root.cellHeight + root.indicatorPadding * 2
        x: root.activeIdx >= 0 ? (root.horizontalPos(root.activeIdx) - root.indicatorPadding) : 0
        y: 0
        nodeSize: root.indicatorNodeSize
        nodeColor: root.indicatorNodeColor
        lineColor: root.indicatorOutlineColor

        Behavior on x {
            NumberAnimation { duration: root.indicatorAnimDuration; easing.type: Easing.OutCubic }
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
                radius: root.workspaceCornerRadius
                color: isOccupied ? root.occupiedColor : root.emptyColor
                border.color: isOccupied ? root.emptyColor : root.occupiedColor
                border.width: isActive ? root.workspaceActiveBorderWidth : root.workspaceBorderWidth
                antialiasing: true
                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutCubic } }
            }

            Text {
                anchors.centerIn: parent
                text: String(workspaceId)
                color: isOccupied ? root.occupiedTextColor : root.emptyTextColor
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
