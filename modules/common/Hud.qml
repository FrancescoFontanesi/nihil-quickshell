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

    // Cyber Nihilism design system (cyber-nihilism/tokens.json, dark state).
    // Pure black/white masses; greys only for secondary lines and text.
    readonly property string mono: "JetBrains Mono"
    readonly property color cnGround: "#000000"
    readonly property color cnInk: "#ffffff"
    readonly property color cnBorderPassive: "#383838"
    readonly property color cnBorderActive: "#737373"
    readonly property color cnTextSecondary: "#a6a6a6"
    readonly property color cnTextMuted: "#8c8c8c"
    readonly property int durMicro: 80
    readonly property int durShort: 160
    readonly property int durMedium: 240
    readonly property int durLong: 400
    readonly property var easeMechanical: [0.2, 0, 0, 1, 1, 1]   // for easing.bezierCurve
    readonly property var easeExit: [0.4, 0, 1, 1, 1, 1]

    // Overlay-layer HUDs hide themselves while a client is fullscreen.
    readonly property bool fullscreen: !!(Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.hasFullscreen)
}
