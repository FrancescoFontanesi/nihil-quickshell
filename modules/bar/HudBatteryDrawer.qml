import "../common"
import QtQuick 2.15
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

HudDrawer {
    id: root
    title: "// SYSTEM RESOURCES"
    titleSize: 14

    // --- UPower Battery Reference ---
    readonly property var battery: UPower.displayDevice
    property int percent: battery && battery.ready
        ? Math.max(0, Math.min(100, Math.round(battery.percentage * 100)))
        : 0
    property bool isCharging: battery && battery.ready && !UPower.onBattery
    readonly property bool full: percent >= 99 && isCharging
    property real energyRate: battery && battery.ready ? Math.abs(battery.changeRate) : 0
    property int timeToEmpty: battery && battery.ready ? battery.timeToEmpty : 0
    property int timeToFull: battery && battery.ready ? battery.timeToFull : 0

    function formatSeconds(sec) {
        if (!sec || isNaN(sec) || sec <= 0) return "--"
        var h = Math.floor(sec / 3600)
        var m = Math.floor((sec % 3600) / 60)
        return h + "h " + (m < 10 ? "0" : "") + m + "m"
    }

    // --- Hardware & Battery Sysfs Telemetry ---
    property int cpuPercent: -1 // -1 = no valid delta yet, rendered as "--%"
    property int cpuTemp: 0
    property string ramUsed: "--"
    property string ramTotal: "--"
    property int ramPercent: 0
    property int cycleCount: 0
    property int batteryHealth: 0

    property real prevTotal: 0
    property real prevIdle: 0

    // Output: temp_c ram_used_gb ram_total_gb ram_pct cpu_total cpu_idle(+iowait) cycles health_pct
    function telemetryScript() {
        return [
            "num() { case $1 in ''|*[!0-9]*) REPLY=0 ;; *) REPLY=$1 ;; esac; }",
            "rd() { v=; read -r v 2>/dev/null < \"$1\"; num \"$v\"; }",
            "zp=; zc=; for d in /sys/class/thermal/thermal_zone*; do read -r ty 2>/dev/null < \"$d/type\" || continue; case $ty in x86_pkg_temp) zp=$d; break ;; TCPU) [ -n \"$zc\" ] || zc=$d ;; esac; done",
            "rd \"${zp:-${zc:-/sys/class/thermal/thermal_zone0}}/temp\"; temp_c=$((REPLY / 1000))",
            "t=0; a=0; while read -r k val _; do case $k in MemTotal:) t=$val ;; MemAvailable:) a=$val ;; esac; done < /proc/meminfo",
            "num \"$t\"; t=$REPLY; num \"$a\"; a=$REPLY; used=$((t - a)); [ \"$used\" -lt 0 ] && used=0",
            "ram_pct=0; if [ \"$t\" -gt 0 ]; then ram_pct=$((used * 100 / t)); fi",
            "ru=$(( (used * 10 + 524288) / 1048576 )); rt=$(( (t * 10 + 524288) / 1048576 ))",
            "read -r _ u nice s i w irq sirq st _ 2>/dev/null < /proc/stat",
            "total=$(( ${u:-0} + ${nice:-0} + ${s:-0} + ${i:-0} + ${w:-0} + ${irq:-0} + ${sirq:-0} + ${st:-0} ))",
            "idle=$(( ${i:-0} + ${w:-0} ))",
            "rd /sys/class/power_supply/BAT1/cycle_count; cycles=$REPLY",
            "rd /sys/class/power_supply/BAT1/charge_full; c_full=$REPLY",
            "rd /sys/class/power_supply/BAT1/charge_full_design; c_des=$REPLY",
            "health=0; if [ \"$c_des\" -gt 0 ]; then health=$(( c_full * 100 / c_des )); fi",
            "echo \"$temp_c $((ru / 10)).$((ru % 10)) $((rt / 10)).$((rt % 10)) $ram_pct $total $idle $cycles $health\""
        ].join("\n")
    }

    Process {
        id: telemetryProcess
        command: ["bash", "-c", root.telemetryScript()]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(/\s+/)
                if (parts.length >= 8) {
                    root.cpuTemp = parseInt(parts[0]) || 0
                    root.ramUsed = parts[1] + " GB"
                    root.ramTotal = parts[2] + " GB"
                    root.ramPercent = parseInt(parts[3]) || 0

                    var total = parseFloat(parts[4]) || 0
                    var idle = parseFloat(parts[5]) || 0

                    if (root.prevTotal > 0 && total > root.prevTotal) {
                        var deltaTotal = total - root.prevTotal
                        var deltaIdle = idle - root.prevIdle
                        root.cpuPercent = Math.max(0, Math.min(100, Math.round((1.0 - (deltaIdle / deltaTotal)) * 100)))
                    }
                    root.prevTotal = total
                    root.prevIdle = idle

                    root.cycleCount = parseInt(parts[6]) || 0
                    root.batteryHealth = parseInt(parts[7]) || 0
                }
            }
        }
    }

    function refreshTelemetry() {
        if (!telemetryProcess.running)
            telemetryProcess.running = true
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.open
        onTriggered: root.refreshTelemetry()
    }

    onOpenChanged: {
        if (open) {
            // Restart the CPU delta so the first value is not an average over the closed period.
            prevTotal = 0
            prevIdle = 0
            cpuPercent = -1
            refreshTelemetry()
        }
    }

    component SegBar: Row {
        property int percent
        height: 8
        spacing: 2

        Repeater {
            model: 10
            delegate: Rectangle {
                width: Math.floor((parent.width - 18) / 10)
                height: parent.height
                color: index < Math.round(percent / 10) ? Hud.fg : "#1c2128"
            }
        }
    }

    component StatBar: Column {
        id: bar
        property string label
        property var value
        property int percent
        spacing: 10

        StatRow {
            width: bar.width
            label: bar.label
            value: bar.value
        }
        SegBar {
            width: bar.width
            percent: bar.percent
        }
    }

    // --- Battery summary below the system telemetry ---
    HudSummary {
        anchors.top: batteryTitle.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        headline: root.full ? "FULL (AC)"
                  : (root.isCharging ? "CHARGING" : "DISCHARGING")
        value: (root.isCharging ? "+" : "") + root.percent + "%"
        valueColor: root.percent <= 15 ? Hud.alert : Hud.fg
        caption: root.full ? "FULLY CHARGED"
                 : (root.isCharging ? "TO FULL  " + root.formatSeconds(root.timeToFull)
                                    : "REMAINING  " + root.formatSeconds(root.timeToEmpty))
        rows: [
            { label: "POWER", value: root.energyRate > 0 ? root.energyRate.toFixed(1) + " W" : "-- W" },
            { label: "HEALTH", value: root.batteryHealth > 0 ? root.batteryHealth + "%" : "--" },
            { label: "CYCLES", value: root.cycleCount > 0 ? root.cycleCount : "--" }
        ]
    }

    HudDivider {
        id: div2
        anchors.top: systemSection.bottom
        anchors.topMargin: 9
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 28
        anchors.rightMargin: 28
    }

    Text {
        id: batteryTitle
        anchors.top: div2.bottom
        anchors.topMargin: 24
        anchors.left: parent.left
        anchors.leftMargin: 20
        text: "// POWER & HARDWARE TELEMETRY"
        color: Hud.textPrimary
        font.family: Hud.font
        font.pixelSize: 14
        font.bold: true
        font.letterSpacing: 1
    }

    // --- System telemetry above the separator ---
    Item {
        id: systemSection
        anchors.top: root.header.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 22
        height: 180

        Column {
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 28

            // CPU temperature has no percentage scale, so it stays above the bars.
            StatRow {
                width: parent.width
                label: "CPU TEMP"
                value: root.cpuTemp > 0 ? (root.cpuTemp + "°C") : "--°C"
                valueColor: root.cpuTemp >= 80 ? Hud.alert : Hud.fg
            }

            StatBar {
                width: parent.width
                label: "CPU LOAD"
                value: root.cpuPercent >= 0 ? root.cpuPercent + "%" : "--%"
                percent: root.cpuPercent
            }

            StatBar {
                width: parent.width
                label: "RAM USAGE"
                value: root.ramUsed + " / " + root.ramTotal + " (" + root.ramPercent + "%)"
                percent: root.ramPercent
            }
        }
    }
}
