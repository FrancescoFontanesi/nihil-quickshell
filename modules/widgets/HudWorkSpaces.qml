import QtQuick 2.12
import QtQml 2.15
import Quickshell
import Quickshell.Hyprland

Item {
    id: root
    focus: false

    property int workspaceCount: 10
    property int perRow: 5
    property int workspaceWidth: 64
    property int workspaceHeight: 64
    property int workspaceSpacing: 24
    property int groupSpacing: 1080
    property int layoutPadding: 24
    property int verticalPadding: 8
    property real scaleFactor: 0.5

    property int indicatorPadding: 12
    property int indicatorNodeSize: 10
    property bool showIndicator: true
    property int indicatorAnimDuration: 200

    property color emptyColor: '#6e000000'
    property color emptyTextColor: "#ffffff"
    property color occupiedColor: '#c5ffffff'
    property color occupiedTextColor: "#000000"
    property int workspaceBorderWidth: 2
    property int workspaceActiveBorderWidth: 4
    property real workspaceCornerRadius: 10

    property color indicatorNodeColor: "#ffffff"
    property color indicatorOutlineColor: "#80ffffff"

    readonly property int layoutWidth: workspaceCount > 0
        ? horizontalPos(workspaceCount - 1) + workspaceWidth
        : workspaceWidth
    readonly property int layoutHeight: workspaceHeight
    readonly property int baseWidth: layoutWidth + layoutPadding * 2
    readonly property int baseHeight: layoutHeight + verticalPadding * 2

    property int activeWorkspaceId: -1

    width: baseWidth * scaleFactor
    height: baseHeight * scaleFactor
    implicitWidth: width
    implicitHeight: height

    ListModel { id: workspaceModel }

    function initializeModel() {
        workspaceModel.clear()
        for (var i = 1; i <= workspaceCount; ++i) {
            workspaceModel.append({ id: i, label: "" + i, occupied: false, active: false })
        }
    }

    function indexForWorkspace(id) {
        for (var i = 0; i < workspaceModel.count; ++i) {
            if (workspaceModel.get(i).id === id) return i
        }
        return -1
    }

    function horizontalPos(idx) {
        if (idx <= 0) return 0
        var base = idx * (workspaceWidth + workspaceSpacing)
        if (idx >= perRow)
            base += groupSpacing - workspaceSpacing
        return base
    }

    function updateIndicatorForIndex(idx) {
        if (idx < 0 || idx >= workspaceModel.count) {
            indicator.visible = false
            indicator.initialized = false
            return
        }

        var destX = layoutPadding + horizontalPos(idx) - indicatorPadding
        var destY = verticalPadding - indicatorPadding

        if (!showIndicator) {
            indicator.visible = false
            indicator.initialized = false
            indicator.x = destX
            indicator.y = destY
            return
        }

        if (!indicator.visible) {
            indicator.initialized = false
            indicator.visible = true
            indicator.x = destX
            indicator.y = destY
            indicator.initialized = true
        } else {
            if (!indicator.initialized) indicator.initialized = true
            indicator.x = destX
            indicator.y = destY
        }
    }

    function refreshIndicatorGeometry() {
        if (activeWorkspaceId === -1) return
        var idx = indexForWorkspace(activeWorkspaceId)
        if (idx >= 0) updateIndicatorForIndex(idx)
    }

    function setActiveWorkspace(id) {
        var idx = indexForWorkspace(id)
        activeWorkspaceId = id

        for (var i = 0; i < workspaceModel.count; ++i)
            workspaceModel.setProperty(i, "active", i === idx)

        updateIndicatorForIndex(idx)
    }

    function syncWorkspaces() {
        if (workspaceModel.count === 0)
            initializeModel()

        var data = Hyprland.workspaces.values
        var seen = {}
        for (var i = 0; i < data.length; ++i) {
            var ws = data[i]
            if (!ws || ws.id <= 0) continue

            var id = parseInt(ws.id, 10)
            if (!isFinite(id)) continue

            var idx = indexForWorkspace(id)
            if (idx < 0) continue
            seen[idx] = true

            var ipcData = ws.lastIpcObject || {}
            var windows = ipcData.windows !== undefined ? ipcData.windows : 0

            var occupied = windows > 0
            var item = workspaceModel.get(idx)
            if (item.occupied !== occupied)
                workspaceModel.setProperty(idx, "occupied", occupied)

            var label = ws.name !== undefined && ws.name !== "" ? ws.name : "" + id
            if (item.label !== label)
                workspaceModel.setProperty(idx, "label", label)
        }

        for (var j = 0; j < workspaceModel.count; ++j) {
            if (!seen[j] && workspaceModel.get(j).occupied)
                workspaceModel.setProperty(j, "occupied", false)
        }

        var focused = Hyprland.focusedWorkspace
        setActiveWorkspace(focused ? focused.id : -1)
    }

    onWorkspaceCountChanged: {
        initializeModel()
        setActiveWorkspace(-1)
    }
    onWorkspaceWidthChanged: refreshIndicatorGeometry()
    onWorkspaceHeightChanged: refreshIndicatorGeometry()
    onWorkspaceSpacingChanged: refreshIndicatorGeometry()
    onGroupSpacingChanged: refreshIndicatorGeometry()
    onLayoutPaddingChanged: refreshIndicatorGeometry()
    onVerticalPaddingChanged: refreshIndicatorGeometry()
    onIndicatorPaddingChanged: refreshIndicatorGeometry()
    onShowIndicatorChanged: refreshIndicatorGeometry()

    Component.onCompleted: {
        initializeModel()
        Hyprland.refreshWorkspaces()
        refreshTimer.restart()
    }

    Timer {
        id: refreshTimer
        interval: 60
        repeat: false
        onTriggered: root.syncWorkspaces()
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            root.syncWorkspaces()
        }
        function onRawEvent(event) {
            var eventName = event.name || ""
            if (eventName.indexOf("workspace") !== -1
                    || eventName.indexOf("window") !== -1
                    || eventName === "focusedmon") {
                Hyprland.refreshWorkspaces()
                refreshTimer.restart()
            }
        }
    }

    Item {
        id: content
        x: 0
        y: 0
        width: baseWidth
        height: baseHeight
        transformOrigin: Item.TopLeft
        scale: scaleFactor

        Item {
            id: workspaceGrid
            x: layoutPadding
            y: verticalPadding
            width: layoutWidth
            height: layoutHeight
            antialiasing:true

            Repeater {
                id: workspaceRepeater
                model: workspaceModel
                delegate: Item {
                    width: root.workspaceWidth
                    height: root.workspaceHeight

                    property int workspaceId: model.id
                    property bool isOccupied: model.occupied
                    property bool isActive: model.active
                    property string label: model.label

                    x: root.horizontalPos(index)
                    y: 0

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
                        text: label
                        color: isOccupied ? root.occupiedTextColor : root.emptyTextColor
                        font.pixelSize: Math.round(Math.min(root.workspaceWidth, root.workspaceHeight) * 0.42)
                        font.weight: Font.DemiBold
                        font.family: "Radjhani"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        renderType: Text.QtRendering
                        Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    }
                }
            }
        }

        Item {
            id: indicator
            z: 10
            visible: false
            width: root.workspaceWidth + root.indicatorPadding * 2
            height: root.workspaceHeight + root.indicatorPadding * 2
            property bool initialized: false

            Behavior on x {
                enabled: indicator.initialized
                NumberAnimation { duration: root.indicatorAnimDuration; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                enabled: indicator.initialized
                NumberAnimation { duration: root.indicatorAnimDuration; easing.type: Easing.OutCubic }
            }

            onWidthChanged: indicatorLines.requestPaint()
            onHeightChanged: indicatorLines.requestPaint()

            Repeater {
                id: indicatorNodes
                model: 4
                delegate: Rectangle {
                    width: root.indicatorNodeSize
                    height: root.indicatorNodeSize
                    color: root.indicatorNodeColor
                    radius: 0
                    property bool isBottom: index >= 2
                    property bool isRight: (index % 2) === 1
                    x: isRight ? indicator.width - width : 0
                    y: isBottom ? indicator.height - height : 0
                    onXChanged: indicatorLines.requestPaint()
                    onYChanged: indicatorLines.requestPaint()
                }
            }

            Canvas {
                id: indicatorLines
                anchors.fill: parent
                visible: root.showIndicator
                onPaint: {
                    var a = indicatorNodes.itemAt(0)
                    var b = indicatorNodes.itemAt(1)
                    var c = indicatorNodes.itemAt(3)
                    var d = indicatorNodes.itemAt(2)
                    if (!a || !b || !c || !d) return

                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.lineWidth = 2
                    ctx.lineJoin = "round"
                    ctx.lineCap = "round"
                    ctx.strokeStyle = root.indicatorOutlineColor

                    function mid(it) { return it.mapToItem(indicatorLines, it.width / 2, it.height / 2) }
                    var pa = mid(a)
                    var pb = mid(b)
                    var pc = mid(c)
                    var pd = mid(d)

                    ctx.beginPath()
                    ctx.moveTo(pa.x, pa.y)
                    ctx.lineTo(pb.x, pb.y)
                    ctx.lineTo(pc.x, pc.y)
                    ctx.lineTo(pd.x, pd.y)
                    ctx.closePath()
                    ctx.stroke()
                }
            }
        }
    }
}
