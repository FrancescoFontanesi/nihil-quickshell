import "../common"
import QtQuick 2.12
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

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

        // Keep the external LLM window synchronized with its HUD.
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
        onStopped: { updateExclusiveZone(); root.syncWithApp() }
    }

    SequentialAnimation {
        id: toUndeploy
        ScriptAction { script: { root.expandPhase = true; root.visualOpen = false } }
        PauseAnimation { duration: expandTotal }
        ScriptAction { script: { root.expandPhase = false } }
        NumberAnimation { target: root; property: "offsetX"; to: initX; duration: 220; easing.type: Easing.InOutCubic }  // from the current offset: may be mid-opening
        ScriptAction { script: { root.expandPhase = true } }
        onStopped: { updateExclusiveZone(); root.syncWithApp() }
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

    // ======== PROVIDERS ========
    LlmModel {
        id: llm
        command: root.command
    }

    // The wrapper window can be hidden or shown without the HUD (its own Escape,
    // a direct keybind): follow it instead of drifting out of sync.
    Connections {
        target: llm
        function onVisibleChanged() { root.syncWithApp() }
        function onRunningChanged() { root.syncWithApp() }
    }

    // Provider tab on the frame's top edge + the provider panel drawn over the wrapper.
    LlmProviders {
        id: providers
        anchors.fill: parent
        z: 10
        llm: llm
        hudOpen: root.visualOpen
        frame: Qt.rect(6 - (root.panelWindow ? root.panelWindow.leftMargin : 0), 4 + root.finalY, root.rectW, root.rectH)
        nodeSize: root.s
    }

    // Input passes through everywhere except the tab and the panel, and only while open.
    Region { id: noInput }
    Region {
        id: providerInput
        Region { item: providers.tab }
        Region { item: providers.panel }
    }
    onVisualOpenChanged: if (panelWindow) panelWindow.mask = visualOpen ? providerInput : noInput

    Connections {
        target: providers
        function onNeedsKeyboardChanged() {
            if (!root.panelWindow) return
            root.panelWindow.focusable = providers.needsKeyboard
            root.panelWindow.WlrLayershell.keyboardFocus = providers.needsKeyboard
                ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            if (providers.needsKeyboard) Qt.callLater(providers.focusPanel)
            else if (llm.visible) llm.run([])   // hand the keyboard back to the wrapper window
        }
    }

    // Reconcile the HUD with the wrapper window's real visibility. Skipped while
    // animating and for 1.5s after the HUD itself toggled the app (a cold start is slow).
    function syncWithApp() {
        if (toDeploy.running || toUndeploy.running || fullscreenActive || !llm.running) return
        if (Date.now() - _lastToggleMs < 1500) { syncRetry.restart(); return }
        if (!llm.visible && visualOpen) toUndeploy.start()
        else if (llm.visible && !visualOpen) toDeploy.start()
    }
    Timer { id: syncRetry; interval: 1600; onTriggered: root.syncWithApp() }
    Component.onCompleted: Qt.callLater(syncWithApp)   // the state may load before the Connections exist

    // ======== EXCLUSIVE ZONE ========
    function updateExclusiveZone() {
        if (!panelWindow) { console.warn("panelWindow not set"); return; }
        panelWindow.exclusiveZone = visualOpen ? panelWindow.reservedWidth : 0;
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
