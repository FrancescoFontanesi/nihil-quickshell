import "../common"
import QtQuick 2.15
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

Item {
    id: root
    anchors.fill: parent

    // The PanelWindow that contains the launcher.
    property PanelWindow panelWindow

    // Geometry / styling (tunable from shell.qml).
    property int s: 32
    property int gap: 12
    property int rectW: 600
    property int rectH: 400
    property url imageSource: Qt.resolvedUrl("../../assets/wofi.png")
    property int maxResults: 80

    // Animation tuning.
    property int staggerStep: 80
    property int animDur: 360
    property real overshoot: 0.4
    readonly property int expandTotal: 3 * staggerStep + animDur

    // Derived geometry.
    readonly property int collapsedSpan: 2 * s + gap
    readonly property int collapsedX: Math.round((width - collapsedSpan) / 2)
    readonly property int collapsedY: Math.round((height - collapsedSpan) / 2)
    readonly property int finalX: Math.round((width - rectW) / 2)
    readonly property int finalY: Math.round((height - rectH) / 2)

    // UI state.
    property bool visualOpen: false
    property bool expandPhase: true
    property alias searchText: searchInput.text
    readonly property var filteredApplications: filterApplications(searchText)

    opacity: (visualOpen || toDeploy.running || toUndeploy.running) ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 220 } }

    // Keep the full-screen overlay click-through while closed, and accept input
    // only over the launcher rectangle while open.
    Region { id: inactiveInputRegion }
    Region { id: activeInputRegion; item: contentFrame }

    GlobalShortcut {
        appid: "launcher"
        name: "toggle"
        description: "Toggle launcher HUD"

        onPressed: {
            root.toggleLauncher()
        }
    }

    Connections {
        target: Hyprland

        function onFocusedWorkspaceChanged() {
            if (root.visualOpen)
                root.closeLauncher()
        }
    }

    SequentialAnimation {
        id: toDeploy
        ScriptAction { script: root.applyOpenState() }
        PauseAnimation { duration: root.expandTotal }
        ScriptAction { script: root.focusSearch() }
    }

    SequentialAnimation {
        id: toUndeploy
        ScriptAction { script: root.applyClosedState() }
        PauseAnimation { duration: root.expandTotal }
        ScriptAction { script: root.expandPhase = false }
    }

    function toggleLauncher() {
        if (visualOpen || toDeploy.running)
            closeLauncher()
        else
            openLauncher()
    }

    function openLauncher() {
        if (toUndeploy.running)
            toUndeploy.stop()
        if (!toDeploy.running)
            toDeploy.start()
    }

    function closeLauncher() {
        if (!visualOpen && !toDeploy.running)
            return
        if (toDeploy.running)
            toDeploy.stop()
        if (!toUndeploy.running)
            toUndeploy.start()
    }

    function applyOpenState() {
        expandPhase = true
        searchInput.text = ""
        applicationsList.currentIndex = -1

        if (panelWindow) {
            panelWindow.mask = activeInputRegion
            panelWindow.focusable = true
            if (panelWindow.WlrLayershell)
                panelWindow.WlrLayershell.keyboardFocus = WlrKeyboardFocus.Exclusive
        }

        visualOpen = true
        Qt.callLater(focusSearch)
        Qt.callLater(resetSelection)
    }

    function applyClosedState() {
        visualOpen = false
        searchInput.text = ""
        searchInput.focus = false

        if (panelWindow) {
            if (panelWindow.WlrLayershell)
                panelWindow.WlrLayershell.keyboardFocus = WlrKeyboardFocus.None
            panelWindow.mask = inactiveInputRegion
            panelWindow.focusable = false
        }
    }

    function focusSearch() {
        if (!visualOpen)
            return
        searchInput.forceActiveFocus(Qt.ShortcutFocusReason)
        searchInput.cursorPosition = searchInput.length
    }

    function resetSelection() {
        applicationsList.currentIndex = applicationsList.count > 0 ? 0 : -1
        applicationsList.positionViewAtBeginning()
    }

    function moveSelection(offset) {
        if (applicationsList.count === 0)
            return

        var next = applicationsList.currentIndex + offset
        if (next < 0)
            next = applicationsList.count - 1
        else if (next >= applicationsList.count)
            next = 0

        applicationsList.currentIndex = next
        applicationsList.positionViewAtIndex(next, ListView.Contain)
    }

    function launchSelected() {
        var index = applicationsList.currentIndex
        if (index < 0 || index >= filteredApplications.length)
            return

        var entry = filteredApplications[index]
        if (!entry)
            return

        entry.execute()
        closeLauncher()
    }

    function normalize(value) {
        return value ? String(value).toLocaleLowerCase().trim() : ""
    }

    function pageStep() {
        return Math.max(1, Math.floor(applicationsList.height / applicationsList.rowHeight))
    }

    function matchScore(entry, query, tokens) {
        var name = normalize(entry.name)
        var genericName = normalize(entry.genericName)
        var comment = normalize(entry.comment)
        var id = normalize(entry.id)
        var haystack = name + " " + genericName + " " + comment + " " + id

        for (var tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++) {
            if (haystack.indexOf(tokens[tokenIndex]) === -1)
                return -1
        }

        if (query.length === 0)
            return 100
        if (name === query)
            return 0
        if (name.indexOf(query) === 0)
            return 10
        if (name.indexOf(" " + query) !== -1)
            return 20
        if (genericName.indexOf(query) === 0)
            return 30
        if (id.indexOf(query) === 0)
            return 40
        if (name.indexOf(query) !== -1)
            return 50
        if (genericName.indexOf(query) !== -1)
            return 60
        if (id.indexOf(query) !== -1)
            return 70
        return 80
    }

    function filterApplications(rawQuery) {
        var query = normalize(rawQuery)
        var tokens = query.length > 0 ? query.split(/\s+/) : []
        var applications = DesktopEntries.applications.values
        var matches = []

        for (var index = 0; index < applications.length; index++) {
            var entry = applications[index]
            var score = matchScore(entry, query, tokens)
            if (score >= 0)
                matches.push({ "entry": entry, "score": score })
        }

        matches.sort(function(left, right) {
            if (left.score !== right.score)
                return left.score - right.score
            return String(left.entry.name).localeCompare(String(right.entry.name))
        })

        return matches.slice(0, root.maxResults).map(function (m) { return m.entry })
    }

    onSearchTextChanged: Qt.callLater(resetSelection)

    Component.onCompleted: applyClosedState()

    // Content rectangle and launcher UI.
    Item {
        id: contentFrame
        z: 1
        width: root.rectW
        height: root.rectH
        x: root.finalX
        y: root.finalY
        opacity: root.visualOpen ? 1 : 0
        visible: opacity > 0 || toUndeploy.running

        Behavior on opacity { CnAnim { duration: Hud.durShort } }

        Rectangle {
            anchors.fill: parent
            color: "#d8000000"  // same plate as LockHud / DeviceMenu

            Image {
                anchors.fill: parent
                source: root.imageSource
                fillMode: Image.PreserveAspectCrop
                smooth: true
            }

            // Plate edge, drawn above the backdrop image so it stays visible.
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 1
                border.color: Hud.borderPassive
            }
        }

        Item {
            anchors {
                fill: parent
                leftMargin: Math.max(64, root.rectW * 0.13)
                rightMargin: Math.max(64, root.rectW * 0.13)
                topMargin: Math.max(76, root.rectH * 0.15)
                bottomMargin: Math.max(58, root.rectH * 0.10)
            }

            Item {
                id: titleLabel
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 28

                Text {
                    id: microLabel
                    x: 0; y: 0
                    text: "APP · INDEX"
                    color: Hud.cnTextMuted
                    font { family: Hud.mono; pixelSize: 9; letterSpacing: 1.0 }
                }

                Text {
                    id: titleText
                    x: 0; y: 11
                    height: 18
                    text: "APPLICATIONS"
                    color: Hud.cnInk
                    font { family: Hud.font; pixelSize: 17; weight: Font.DemiBold; letterSpacing: 1.2 }
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    anchors { right: parent.right; verticalCenter: titleText.verticalCenter }
                    text: String(applicationsList.count).padStart(3, "0") + " / " + String(root.maxResults).padStart(3, "0")
                    color: Hud.cnTextMuted
                    font { family: Hud.mono; pixelSize: 9; letterSpacing: 1.0 }
                }
            }

            Item {
                id: searchFrame
                anchors {
                    left: parent.left
                    right: parent.right
                    top: titleLabel.bottom
                    topMargin: 12
                }
                height: 62

                CnCut {
                    anchors.fill: parent
                    br: 8
                    fill: Hud.cnGround
                    edge: searchInput.activeFocus ? Hud.cnInk : Hud.cnBorderActive
                    edgeWidth: searchInput.activeFocus ? 2 : 1
                }

                // Armoured top-left corner while armed.
                Shape {
                    visible: searchInput.activeFocus
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: Hud.cnInk
                        strokeWidth: -1
                        startX: 0; startY: 0
                        PathLine { x: 12; y: 0 }
                        PathLine { x: 0; y: 12 }
                        PathLine { x: 0; y: 0 }
                    }
                }

                Text {
                    anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                    text: ">"
                    color: Hud.cnTextMuted
                    font { family: Hud.mono; pixelSize: 22 }
                }

                TextInput {
                    id: searchInput
                    anchors {
                        left: parent.left
                        leftMargin: 52
                        right: parent.right
                        rightMargin: 18
                        top: parent.top
                        bottom: parent.bottom
                    }
                    color: Hud.cnInk
                    selectionColor: Hud.cnInk
                    selectedTextColor: Hud.cnGround
                    font { family: Hud.font; pixelSize: 22; weight: Font.Medium; letterSpacing: 1 }
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    selectByMouse: true
                    activeFocusOnTab: true

                    Keys.priority: Keys.BeforeItem
                    Keys.onPressed: function(event) {
                        var ctrl = (event.modifiers & Qt.ControlModifier) !== 0
                        var step = 0
                        if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && event.key === Qt.Key_N))
                            step = 1
                        else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && event.key === Qt.Key_P))
                            step = -1
                        else if (event.key === Qt.Key_PageDown)
                            step = root.pageStep()
                        else if (event.key === Qt.Key_PageUp)
                            step = -root.pageStep()

                        if (event.key === Qt.Key_Escape) {
                            root.closeLauncher()
                            event.accepted = true
                        } else if (step !== 0) {
                            root.moveSelection(step)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.launchSelected()
                            event.accepted = true
                        }
                    }
                }

                Text {
                    anchors {
                        left: searchInput.left
                        right: searchInput.right
                        verticalCenter: parent.verticalCenter
                    }
                    visible: searchInput.text.length === 0
                    text: "SEARCH APPLICATIONS"
                    color: Hud.cnTextMuted
                    font { family: Hud.mono; pixelSize: 13; letterSpacing: 1.2 }
                    elide: Text.ElideRight
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.IBeamCursor
                    onPressed: function(mouse) {
                        searchInput.forceActiveFocus(Qt.MouseFocusReason)
                        mouse.accepted = false
                    }
                }
            }

            ListView {
                id: applicationsList
                property int rowHeight: 68
                anchors {
                    left: parent.left
                    right: parent.right
                    top: searchFrame.bottom
                    topMargin: 16
                    bottom: parent.bottom
                    bottomMargin: 36
                }
                clip: true
                spacing: 6
                model: root.filteredApplications
                currentIndex: -1
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: applicationDelegate
                    required property var modelData
                    required property int index
                    readonly property bool selected: ListView.isCurrentItem

                    width: applicationsList.width
                    height: applicationsList.rowHeight

                    // Selected rows invert; idle rows are an outline, hover lights the edge.
                    CnCut {
                        anchors.fill: parent
                        br: 8
                        fill: applicationDelegate.selected ? Hud.cnInk : Qt.transparent
                        edge: (applicationDelegate.selected || delegateMouse.containsMouse) ? Hud.cnInk : Hud.cnBorderPassive
                    }

                    IconImage {
                        id: applicationIcon
                        anchors {
                            left: parent.left
                            leftMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        width: 42
                        height: 42
                        source: Quickshell.iconPath(applicationDelegate.modelData.icon, "application-x-executable")
                        asynchronous: true
                    }

                    Item {
                        anchors {
                            left: applicationIcon.right
                            leftMargin: 16
                            right: parent.right
                            rightMargin: 36  // keeps text clear of the index
                            top: parent.top
                            bottom: parent.bottom
                        }

                        Text {
                            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 11 }
                            text: applicationDelegate.modelData.name
                            color: applicationDelegate.selected ? Hud.cnGround : Hud.cnInk
                            font { family: Hud.font; pixelSize: 18; weight: Font.DemiBold }
                            elide: Text.ElideRight
                        }

                        Text {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 10 }
                            text: applicationDelegate.modelData.genericName
                                  || applicationDelegate.modelData.comment
                                  || applicationDelegate.modelData.id
                            color: applicationDelegate.selected ? Hud.cnGround : Hud.cnTextMuted
                            font { family: Hud.mono; pixelSize: 10; letterSpacing: 0.6 }
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        anchors { right: parent.right; rightMargin: 14; top: parent.top; topMargin: 11 }
                        text: String(applicationDelegate.index + 1).padStart(2, "0")
                        color: applicationDelegate.selected ? Hud.cnGround : Hud.cnTextMuted
                        font { family: Hud.mono; pixelSize: 9; letterSpacing: 1.0 }
                    }

                    MouseArea {
                        id: delegateMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: applicationsList.currentIndex = applicationDelegate.index
                        onClicked: root.launchSelected()
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: applicationsList.count === 0
                    text: "NO APPLICATIONS FOUND"
                    color: Hud.cnTextMuted
                    font { family: Hud.mono; pixelSize: 11; letterSpacing: 1.2 }
                }
            }
        }
    }

    // Corner nodes and outline that animate with the HUD.
    HudStaggerFrame {
        z: 2
        anchors.fill: parent
        open: root.visualOpen
        animate: root.expandPhase
        openRect: Qt.rect(root.finalX, root.finalY, root.rectW, root.rectH)
        closedPos: Qt.point(root.collapsedX, root.collapsedY)
        nodeSize: root.s
        gap: root.gap
        nodeRadius: 2
        staggerStep: root.staggerStep
        animDur: root.animDur
        overshoot: root.overshoot
        lineWidth: 2
        lineColor: "#60ffffff"
    }
}
