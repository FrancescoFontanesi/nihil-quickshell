import "../common"
import QtQuick 2.12
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import QtQml 2.15

Item {
    id: lock
    anchors.fill: parent

    // ======== PARAMS / STATE ========
    property PanelWindow panelWindow

    // Geometry
    property int s: 8
    property int gap: 12
    property int rectW: 396
    property int rectH: 600
    property int shiftX: 100
    property int initX: 804
    property real offsetX: 0
    property int initY: Math.round((height - (2*s)) / 2)
    property int finalY: Math.round((height - rectH) / 2)

    // Animations synchronized with LlmHud.qml
    property int staggerStep: 60
    property int animDur: 360
    property real overshoot: 0.8
    property int expandTotal: 3 * staggerStep + animDur

    // UI/animation state
    property bool visualOpen: false
    property bool expandPhase: true
    property bool backgroundReady: false

    readonly property bool fullscreenActive: Hud.fullscreen
    readonly property bool sideOpen: deviceMenuOverlay.visible && deviceMenuOverlay.width > 10

    property int rightMargin: panelWindow && panelWindow.rightMargin !== undefined ? panelWindow.rightMargin : 0

    // Stop before the original frame (assets/right.png: 64px).
    readonly property int screenRightX: width + rightMargin
    readonly property int openRightX: screenRightX - 16
    readonly property int baseOpenLeft: openRightX - rectW

    readonly property int panelWidth: 175
    readonly property int panelGap: 14
    readonly property int panelsLeft: Math.round((rectW - (2 * panelWidth + panelGap)) / 2)
    readonly property int networkPanelX: panelsLeft
    readonly property int actionsPanelX: panelsLeft + panelWidth + panelGap
    readonly property bool ecoMode: PowerProfiles.profile === PowerProfile.PowerSaver
    property bool airplaneMode: false

    // Power actions need two clicks: the first arms the tile for 3s.
    property int armedPower: -1
    Timer {
        id: disarmTimer
        interval: 3000
        onTriggered: lock.armedPower = -1
    }

    function resetOpenState() {
        armedPower = -1
        expandPhase = true
        visualOpen = false
        backgroundReady = false
        deviceMenuOverlay.menu = ""
    }

    function restartProc(p) {
        p.running = false
        p.running = true
    }

    function toggleEcoMode() {
        PowerProfiles.profile = ecoMode ? PowerProfile.Balanced : PowerProfile.PowerSaver
    }

    function toggleAirplaneMode() {
        airplaneMode = !airplaneMode
        Quickshell.execDetached(airplaneMode ? ["rfkill", "block", "all"] : ["rfkill", "unblock", "all"])
        refreshTimer.restart()
    }

    Timer {
        id: refreshTimer
        interval: 1800
        onTriggered: {
            deviceMenuOverlay.refresh()
            lock.restartProc(systemStateScan)
        }
    }

    Timer {
        interval: 10000
        repeat: true
        running: lock.visualOpen
        onTriggered: lock.restartProc(systemStateScan)
    }

    Process {
        id: systemStateScan
        command: ["rfkill", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var hasSoftBlocked = text.indexOf("Soft blocked: yes") !== -1
                var hasSoftUnblocked = text.indexOf("Soft blocked: no") !== -1
                lock.airplaneMode = hasSoftBlocked && !hasSoftUnblocked
            }
        }
    }

    Component.onCompleted: {
        systemStateScan.running = true
    }

    visible: !fullscreenActive

    onFullscreenActiveChanged: {
        if (!fullscreenActive)
            return

        toDeployLock.stop()
        toUndeployLock.stop()
        offsetX = 0
        resetOpenState()
        if (panelWindow)
            panelWindow.clickThrough = true
    }

    signal toggled()
    property double lastToggleTriggerTime: 0

    function triggerToggle() {
        var now = Date.now()
        if (now - lastToggleTriggerTime < 250) return
        if (lock.fullscreenActive) return
        if (toDeployLock.running || toUndeployLock.running) return
        lastToggleTriggerTime = now
        lock.toggled()
        if (!lock.visualOpen) toDeployLock.start()
        else toUndeployLock.start()
    }

    // ======== HOTKEY: toggle HUD only ========
    GlobalShortcut {
        appid: "lock"
        name: "toggle"
        description: "Toggle HUD rectangle (right-to-left)"
        onPressed: lock.triggerToggle()
    }

    // ======== WORKSPACE CHANGE: close the HUD only ========
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            if (toDeployLock.running || toUndeployLock.running) return
            if (lock.visualOpen) toUndeployLock.start()
        }
    }

    // ======== ANIMATIONS ========
    SequentialAnimation {
        id: toDeployLock
        ScriptAction {
            script: {
                lock.expandPhase = false
                lock.visualOpen = false
                lock.backgroundReady = false
                lock.offsetX = 0
                if (panelWindow) panelWindow.clickThrough = false
                lock.restartProc(systemStateScan)
            }
        }
        NumberAnimation { target: lock; property: "offsetX"; from: 0; to: shiftX; duration: 220; easing.type: Easing.OutCubic }
        ScriptAction {
            script: {
                lock.expandPhase = true
                lock.visualOpen = true
                lock.backgroundReady = true
            }
        }
    }

    SequentialAnimation {
        id: toUndeployLock
        ScriptAction {
            script: {
                lock.resetOpenState()
            }
        }
        PauseAnimation { duration: expandTotal }
        ScriptAction { script: { lock.expandPhase = false } }
        NumberAnimation { target: lock; property: "offsetX"; from: shiftX; to: 0; duration: 220; easing.type: Easing.InOutCubic }
        ScriptAction { script: { lock.expandPhase = true } }
        onStopped: {
            if (panelWindow) panelWindow.clickThrough = true
        }
    }

    // A click outside both panels closes the HUD
    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: lock.visualOpen
        onClicked: (mouse) => {
            var insideMain = mouse.x >= baseOpenLeft && mouse.x < baseOpenLeft + rectW
                             && mouse.y >= finalY && mouse.y < finalY + rectH
            var sideLeft = baseOpenLeft + deviceMenuOverlay.x
            var insideSide = deviceMenuOverlay.width > 0 && mouse.x >= sideLeft
                             && mouse.x < sideLeft + deviceMenuOverlay.width
                             && mouse.y >= finalY && mouse.y < finalY + rectH
            if (!insideMain && !insideSide)
                lock.triggerToggle()
        }
    }

    // Corner nodes + outline for the main panel
    HudStaggerFrame {
        anchors.fill: parent
        z: 20
        open: lock.visualOpen
        animate: lock.expandPhase
        openRect: Qt.rect(lock.baseOpenLeft, lock.finalY, lock.rectW, lock.rectH)
        closedPos: Qt.point(lock.initX - lock.offsetX, lock.initY)
        nodeSize: lock.s
        gap: lock.gap
        staggerStep: lock.staggerStep
        animDur: lock.animDur
        overshoot: lock.overshoot
    }

    // ======== BACKGROUND (avoids overlapping assets/right.png) ========
    Rectangle {
        z: 0
        x: baseOpenLeft
        y: finalY
        width: rectW
        height: rectH
        radius: 0
        color: '#d8000000'
        border.width: 1
        border.color: Hud.borderPassive
        opacity: lock.backgroundReady ? 1 : 0
        visible: opacity > 0.001

        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }

    // One icon tile for the quick toggles and the power column
    component IconTile: Item {
        id: tile
        property url icon
        property int iconSize: 120
        property real hoverScale: 1.15
        property real iconOpacity: 1
        property bool armed: false
        signal clicked()

        transformOrigin: Item.Center
        scale: tileMouse.containsMouse ? hoverScale : 1

        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Image {
            anchors.centerIn: parent
            source: tile.icon
            sourceSize.width: tile.iconSize
            sourceSize.height: tile.iconSize
            fillMode: Image.PreserveAspectFit
            smooth: true
            opacity: tile.iconOpacity
        }

        // Armed (critical action awaiting confirmation): 2px ink cut + CONFIRM.
        CnCut {
            anchors.fill: parent
            anchors.margins: 4
            visible: tile.armed
            br: 8
            edge: Hud.cnInk
            edgeWidth: 2
        }

        Text {
            visible: tile.armed
            anchors.top: parent.bottom
            anchors.topMargin: 2
            anchors.horizontalCenter: parent.horizontalCenter
            text: "CONFIRM"
            color: Hud.cnInk
            font.family: Hud.mono
            font.pixelSize: 9
            font.letterSpacing: 1.0
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: tile.clicked()
        }
    }

    // ======== CONTROLS ========
    Rectangle {
        id: controls
        z: 1
        opacity: backgroundReady ? 1 : 0
        visible: opacity > 0.001
        color: "transparent"
        x: baseOpenLeft
        y: finalY
        width: rectW
        height: rectH
        clip: false

        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        // Technical vertical divider
        Item {
            x: lock.panelsLeft + lock.panelWidth + Math.round(lock.panelGap / 2)
            y: 42
            width: 8
            height: parent.height - 84

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 1
                height: parent.height
                color: Hud.cnBorderPassive
            }
            Repeater {
                model: 2
                delegate: Rectangle {
                    width: 6
                    height: 6
                    color: Hud.cnInk
                    x: 1
                    y: index === 0 ? 0 : parent.height - height
                }
            }
        }

        // Quick-controls column (Wi-Fi, Bluetooth, Airplane, Eco)
        Grid {
            x: lock.networkPanelX + Math.round((lock.panelWidth - Math.min(200, Math.round(lock.panelWidth * 0.6))) / 2)
            y: 48
            columns: 1
            spacing: 8

            Repeater {
                model: [
                    { icon: Qt.resolvedUrl("../../assets/wifi.png"),     menu: "wifi" },
                    { icon: Qt.resolvedUrl("../../assets/blue.png"),     menu: "bluetooth" },
                    { icon: Qt.resolvedUrl("../../assets/airplane.png"), key: "airplane" },
                    { icon: Qt.resolvedUrl("../../assets/eco.png"),      key: "eco" }
                ]

                delegate: IconTile {
                    required property var modelData
                    readonly property bool active: modelData.menu === "wifi" ? deviceMenuOverlay.wifi.enabled
                                                : modelData.menu === "bluetooth" ? deviceMenuOverlay.bluetooth.enabled
                                                : modelData.key === "airplane" ? lock.airplaneMode
                                                : modelData.key === "eco" ? lock.ecoMode
                                                : false

                    width: 105
                    height: 120
                    icon: modelData.icon
                    iconOpacity: active ? 0.95 : 0.40
                    onClicked: {
                        if (modelData.menu) {
                            deviceMenuOverlay.open(modelData.menu)
                            return
                        }
                        if (modelData.key === "eco") {
                            lock.toggleEcoMode()
                            return
                        }
                        if (modelData.key === "airplane") {
                            lock.toggleAirplaneMode()
                            return
                        }
                    }
                }
            }
        }

        // Wi-Fi / Bluetooth side drawer
        DeviceMenu {
            id: deviceMenuOverlay
            z: 10
            x: -4 - width  // sits 4px off the main panel
            height: parent.height
            panelWindow: lock.panelWindow
            hudOpen: lock.visualOpen
            onSystemChanged: lock.restartProc(systemStateScan)
        }

        // Power column (reboot, shutdown, suspend)
        Column {
            x: lock.actionsPanelX
            y: 70
            width: lock.panelWidth
            spacing: 27.5
            opacity: lock.visualOpen ? 1 : 0
            visible: lock.visualOpen || opacity > 0.001
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Repeater {
                model: [
                    { icon: Qt.resolvedUrl("../../assets/reboot.png"),   cmd: ["systemctl", "reboot"] },
                    { icon: Qt.resolvedUrl("../../assets/shutdown.png"), cmd: ["systemctl", "poweroff"] },
                    { icon: Qt.resolvedUrl("../../assets/lock.png"),     cmd: ["systemctl", "suspend"] }
                ]

                IconTile {
                    required property var modelData
                    required property int index
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 105
                    height: 120
                    icon: modelData.icon
                    hoverScale: 1.2
                    armed: lock.armedPower === index
                    onClicked: {
                        if (!armed) {
                            lock.armedPower = index
                            disarmTimer.restart()
                            return
                        }
                        lock.armedPower = -1
                        toUndeployLock.start()
                        Quickshell.execDetached(modelData.cmd)
                    }
                }
            }
        }
    }

    // Corner nodes + outline for the expanded left panel (Wi-Fi/Bluetooth)
    HudCornerFrame {
        z: 20
        visible: lock.sideOpen
        x: controls.x + deviceMenuOverlay.x
        y: controls.y
        width: deviceMenuOverlay.width
        height: lock.rectH
        nodeSize: lock.s
    }

}