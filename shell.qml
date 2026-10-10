import QtQuick 2.15
import Quickshell
import Quickshell.Wayland
import "./modules/common"
import "./modules/bar"
import "./modules/hud"

ShellRoot {
    id: root

    // Screen-edge chrome: top bar (clock, workspaces), bottom bar (battery, volume,
    // brightness), decorative left/right strips, and their flyout drawers.
    EdgeOverlayLayout {
        thickness: 64
        topSource: Qt.resolvedUrl("./assets/top.png")
        bottomSource: Qt.resolvedUrl("./assets/bottom.png")
        leftSource: Qt.resolvedUrl("./assets/left.png")
        rightSource: Qt.resolvedUrl("./assets/right.png")
    }

    // Overlay HUDs: margins below are calibrated against the edge artwork.

    // --- LEFT HUD: ChatGPT Companion ---
    PanelWindow {
        id: hudWin
        WlrLayershell.layer: WlrLayer.Overlay
        aboveWindows: true
        color: "transparent"
        mask: Region {} // Passthrough: input handled by external companion window

        anchors { left: true; top: true; bottom: true }
        implicitWidth: 880

        // Margin calibration relative to left screen edge
        property int leftMargin: -56
        margins { left: leftMargin; bottom: 14 }

        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore

        ChatGPTHud {
            anchors.fill: parent
            panelWindow: hudWin
            command: "/home/nihil/Extra/LLM-PyGObject/llm-wrapper"

            // Geometry & Calibration
            rectW: 808
            rectH: 1300
            shiftX: 380
        }
    }

    // --- RIGHT HUD: System Controls & Lock/Connectivity ---
    PanelWindow {
        WlrLayershell.layer: WlrLayer.Top
        aboveWindows: true
        color: "transparent"
        visible: lockHud.visualOpen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore

        MouseArea {
            anchors.fill: parent
            onClicked: lockHud.triggerToggle()
        }
    }

    PanelWindow {
        id: hudLock
        WlrLayershell.layer: WlrLayer.Overlay
        aboveWindows: true
        color: "transparent"

        anchors { right: true; top: true; bottom: true }
        implicitWidth: 850

        // Margin calibration relative to right screen edge
        property int rightMargin: -72
        margins { right: rightMargin; bottom: 14 }

        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore

        // Click-through management (LockHud toggles clickThrough when deployed/undeployed)
        property bool clickThrough: true
        readonly property var emptyRegion: Region {}
        mask: clickThrough ? emptyRegion : null

        LockHud {
            id: lockHud
            anchors.fill: parent
            panelWindow: hudLock

            // Geometry & Calibration
            shiftX: 200

            onToggled: {
                if (!lockHud.visualOpen && launcherHud.visualOpen)
                    launcherHud.closeLauncher()
            }
        }
    }

    // --- CENTER HUD: Application Launcher ---
    PanelWindow {
        id: launcherWin
        WlrLayershell.layer: WlrLayer.Overlay
        aboveWindows: true
        color: "transparent"

        // Fullscreen overlay surface (LauncherHud dynamically sets panelWindow.mask)
        anchors { left: true; right: true; top: true; bottom: true }
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}

        LauncherHud {
            id: launcherHud
            anchors.fill: parent
            panelWindow: launcherWin

            // Geometry & Calibration
            s: 8
            rectW: 1000
            rectH: 800

            onVisualOpenChanged: {
                if (visualOpen && lockHud.visualOpen)
                    lockHud.triggerToggle()
            }
        }
    }
}
