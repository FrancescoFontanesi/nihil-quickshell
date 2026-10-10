import QtQuick 2.15
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../common"

Item {
    id: api

    // Size
    property int thickness: 32

    // Sources for each edge
    property url topSource: ""
    property url bottomSource: ""
    property url leftSource: ""
    property url rightSource: ""

    // Any workspace or focus change closes both flyouts
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { clock.drawerOpen = false; battery.drawerOpen = false }
        function onActiveToplevelChanged() { clock.drawerOpen = false; battery.drawerOpen = false }
    }

    component DrawerScrim: PanelWindow {
        required property var owner
        visible: owner.drawerOpen
        WlrLayershell.layer: WlrLayer.Top
        aboveWindows: true
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore

        MouseArea {
            anchors.fill: parent
            onClicked: owner.drawerOpen = false
        }
    }

    // Overlay window hosting one flyout drawer on the top or bottom edge
    component DrawerWindow: PanelWindow {
        required property var owner
        required property Item drawer
        property bool atTop: true
        WlrLayershell.layer: WlrLayer.Overlay
        aboveWindows: true
        color: "transparent"
        visible: owner.drawerOpen || drawer.height > 0
        anchors { top: atTop; bottom: !atTop }
        margins {
            top: atTop ? drawer.drawerMargin : 0
            bottom: atTop ? 0 : drawer.drawerMargin
        }
        implicitWidth: drawer.drawerWidth
        implicitHeight: drawer.drawerHeight + 10
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore

        // Declared before the drawer child so it sits below it
        MouseArea {
            anchors.fill: parent
            onClicked: owner.drawerOpen = false
        }
    }

    // --- TOP BAR ---
    PanelWindow {
        id: topPanel
        anchors { top: true; left: true; right: true }
        margins { top: -8; left: -api.thickness - 8; right: -api.thickness - 8 }
        implicitHeight: api.thickness
        exclusiveZone: api.thickness
        aboveWindows: true
        color: "transparent"
        mask: defaultTopMask

        Region {
            id: defaultTopMask
            Region { item: clock }
            Region { item: workspaces }
        }

        HudClock {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
        }

        HudWorkSpaces {
            id: workspaces
            anchors.horizontalCenter: parent.horizontalCenter
            y: 18
        }

        Image {
            z: -1
            anchors.fill: parent
            source: api.topSource
            asynchronous: true
        }
    }

    // --- CLOCK FLYOUT DRAWER OVERLAY ---
    DrawerScrim { owner: clock }

    DrawerWindow {
        owner: clock
        drawer: clockDrawer

        HudClockDrawer {
            id: clockDrawer
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            open: clock.drawerOpen
            onCloseRequested: clock.drawerOpen = false
        }
    }

    // --- BOTTOM BAR ---
    PanelWindow {
        id: bottomPanel
        anchors { bottom: true; left: true; right: true }
        margins { bottom: -8; left: -api.thickness - 7; right: -api.thickness - 7 }
        implicitHeight: api.thickness
        exclusiveZone: api.thickness
        aboveWindows: true
        color: "transparent"
        mask: defaultBottomMask

        Region {
            id: defaultBottomMask
            Region { item: battery }
            Region { item: volume }
            Region { item: brightness }
        }

        HudBattery {
            id: battery
            anchors.centerIn: parent
            barWidth: 340
            barHeight: 32
            segments: Math.floor(barWidth / 12)
            radius: 2
        }

        HudVolumeBar {
            id: volume
            s: 4
            x: parent.width / 2 + 240
            y: -10
            rectW: 260
            rectH: 24
        }

        HudBrightnessBar {
            id: brightness
            s: 4
            x: parent.width / 2 - 510
            y: -10
            rectW: 260
            rectH: 24
        }

        Image {
            z: -1
            anchors.fill: parent
            source: api.bottomSource
            asynchronous: true
        }
    }

    // --- BATTERY FLYOUT DRAWER OVERLAY ---
    DrawerScrim { owner: battery }

    DrawerWindow {
        owner: battery
        drawer: batteryDrawer
        atTop: false

        HudBatteryDrawer {
            id: batteryDrawer
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            open: battery.drawerOpen
            onCloseRequested: battery.drawerOpen = false
        }
    }

    // --- LEFT ---
    PanelWindow {
        id: leftPanel
        anchors { left: true; top: true; bottom: true }
        margins { left: -2; top: -api.thickness * 0.3; bottom: -api.thickness * 0.3 }
        implicitWidth: api.thickness + 8
        exclusiveZone: api.thickness + 3
        mask: Region {}
        color: "transparent"
        aboveWindows: true
        exclusionMode: ExclusionMode.Ignore

        Image {
            anchors.fill: parent
            source: api.leftSource
            asynchronous: true
        }
    }

    // --- RIGHT ---
    PanelWindow {
        id: rightPanel
        anchors { right: true; top: true; bottom: true }
        margins { top: -api.thickness * 0.3; bottom: -api.thickness * 0.3; right: -2 }
        implicitWidth: api.thickness + 8
        exclusiveZone: api.thickness + 3
        mask: Region {}
        color: "transparent"
        aboveWindows: true

        Image {
            anchors.fill: parent
            source: api.rightSource
            asynchronous: true
        }
    }
}
