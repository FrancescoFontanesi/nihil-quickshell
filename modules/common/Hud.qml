pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Shared design tokens (named after style.json, terminal_dark) and global HUD state.
Singleton {
    readonly property string font: "Rajdhani, sans-serif"

    readonly property color fg: "#ffffff"           // signal.primary
    readonly property color dim: "#80ffffff"        // outlines between corner nodes
    readonly property color alert: "#ff5555"
    readonly property color textPrimary: "#f4f6f7"
    readonly property color textSecondary: "#c9ced3"
    readonly property color textMuted: "#9299a1"
    readonly property color textGhost: "#555b63"
    readonly property color borderPassive: "#24282e"
    readonly property color borderSecondary: "#3e434b"
    readonly property color surfaceInactive: "#1b1e23"
    readonly property color bgRaised: "#0d0f12"
    readonly property color panelBg: "#f007080a"

    // Overlay-layer HUDs hide themselves while a client is fullscreen.
    readonly property bool fullscreen: !!(Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.hasFullscreen)
}
