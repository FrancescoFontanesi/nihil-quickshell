import "../common"
import QtQuick 2.12
import Quickshell.Io

HudLevelBar {
    id: root

    iconSource: Qt.resolvedUrl("../../assets/brightness.png")
    iconTopMargin: 0

    function updatePercent(rawValue) {
        const value = parseInt(String(rawValue).trim(), 10)
        if (!isNaN(value))
            root.percent = Math.max(0, Math.min(100, value))
    }

    function queryBrightness() {
        if (!initBrightness.running)
            initBrightness.running = true
    }

    Process {
        id: initBrightness
        command: ["brightnessctl", "-c", "backlight", "-m", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(",")
                if (parts.length >= 4) {
                    root.updatePercent(parts[3])
                }
            }
        }
    }

    Process {
        id: udevBrightness
        command: ["udevadm", "monitor", "-s", "backlight", "-u"]
        running: true
        stdout: SplitParser {
            onRead: data => root.queryBrightness()
        }
    }

    Component.onCompleted: root.queryBrightness()
}
