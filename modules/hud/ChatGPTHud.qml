import "../common"
import QtQuick 2.12
import Quickshell
import Quickshell.Hyprland

Item {
    id: root
    anchors.fill: parent

    // ======== PARAMS / STATE ========
    property PanelWindow panelWindow
    property string command: ""

    // Geometry
    property int s: 8
    property int gap: 12
    property int rectW: 700
    property int rectH: 1264
    property int shiftX: 356
    property int initX: 0
    property real offsetX: initX
    property int initY: Math.round((height - (2*s)) / 2)
    property int finalY: Math.round((height - rectH) / 2)


    // Animations
    property int staggerStep: 60
    property int animDur: 360
    property real overshoot: 0.8
    property int expandTotal: 3 * staggerStep + animDur

    // UI/animation state
    property bool visualOpen: false
    property bool expandPhase: true

    // PanelWindow uses the Overlay layer, which stays above fullscreen clients
    // unless it is explicitly hidden.
    readonly property bool fullscreenActive: Hud.fullscreen

    visible: !fullscreenActive

    onFullscreenActiveChanged: {
        if (!fullscreenActive)
            return

        var wasOpen = visualOpen || toDeploy.running
        toDeploy.stop()
        toUndeploy.stop()
        visualOpen = false
        expandPhase = true
        offsetX = initX
        updateExclusiveZone()

        // Keep the external ChatGPT window synchronized with its HUD.
        if (wasOpen)
            toggleAppOnce(true)
    }

    // ======== HOTKEY: synchronized toggle ========
    GlobalShortcut {
        appid: "hud"; name: "toggle"; description: "Toggle HUD rectangle"
        onPressed: root.triggerToggle()
    }

    property double _lastShortcutTime: 0
    function triggerToggle() {
        var now = Date.now()
        if (now - _lastShortcutTime < 250) return
        _lastShortcutTime = now

        if (root.fullscreenActive) return
        if (toDeploy.running || toUndeploy.running) return
        if (!root.visualOpen) {    // OPEN sequence
            toDeploy.start()
            toggleAppOnce()
        } else {                   // CLOSE sequence
            toUndeploy.start()
            toggleAppOnce()
        }
    }

    // ======== WORKSPACE CHANGE: close the HUD and the app, even mid-opening ========
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            if (toUndeploy.running || !(root.visualOpen || toDeploy.running)) return
            toDeploy.stop()
            toUndeploy.start()
            // Forced: the opening toggle may be younger than the debounce window.
            toggleAppOnce(true)
        }
    }

    // ======== ANIMATIONS ========
    SequentialAnimation {
        id: toDeploy
        ScriptAction { script: { root.expandPhase = false; root.visualOpen = false } }
        NumberAnimation { target: root; property: "offsetX"; from: initX; to: initX + shiftX; duration: 220; easing.type: Easing.OutCubic }
        ScriptAction { script: { root.expandPhase = true; root.visualOpen = true } }
        onStopped: updateExclusiveZone()
    }

    SequentialAnimation {
        id: toUndeploy
        ScriptAction { script: { root.expandPhase = true; root.visualOpen = false } }
        PauseAnimation { duration: expandTotal }
        ScriptAction { script: { root.expandPhase = false } }
        NumberAnimation { target: root; property: "offsetX"; to: initX; duration: 220; easing.type: Easing.InOutCubic }  // from the current offset: may be mid-opening
        ScriptAction { script: { root.expandPhase = true } }
        onStopped: updateExclusiveZone()
    }

    // ======== 4 CORNER NODES + OUTLINE ========
    HudStaggerFrame {
        anchors.fill: parent
        open: root.visualOpen
        animate: root.expandPhase
        openRect: Qt.rect(6 - (root.panelWindow ? root.panelWindow.leftMargin : 0), 4 + root.finalY, root.rectW, root.rectH)
        closedPos: Qt.point(root.offsetX, root.initY)
        nodeSize: root.s
        gap: root.gap
        staggerStep: root.staggerStep
        animDur: root.animDur
        overshoot: root.overshoot
        lineWidth: 2
    }

    // ======== EXCLUSIVE ZONE ========
    function updateExclusiveZone() {
        if (!panelWindow) { console.warn("panelWindow not set"); return; }
        panelWindow.exclusiveZone = visualOpen ? panelWindow.implicitWidth : 0;
    }

    // ======== APP TOGGLE (debounced) ========
    property double _lastToggleMs: 0
    property int cmdDebounceMs: 300
    function toggleAppOnce(force) {
        var now = Date.now()
        if (!force && now - _lastToggleMs < cmdDebounceMs) return
        _lastToggleMs = now
        if (command && command.length) Quickshell.execDetached([command, "--toggle"])
        else console.warn("toggle command not set")
    }
}
