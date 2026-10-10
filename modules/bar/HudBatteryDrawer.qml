import "../common"
import QtQuick 2.15
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

HudDrawer {
    id: root
    code: "PWR · " + (battery && battery.nativePath ? String(battery.nativePath).toUpperCase() : "BAT")
    title: "SYSTEM RESOURCES"
    drawerHeight: 344
    statusCode: powerStatus().code
    statusText: powerStatus().text

    function powerStatus() {
        if (full) return { code: "OK", text: "FULLY CHARGED" }
        if (isCharging) return { code: "ACT", text: "CHARGING · " + percent + "%" }
        if (holding) return { code: "IDL", text: "ON AC · HOLD · " + percent + "%" }
        if (percent <= 5) return { code: "ERR", text: "CRITICAL · " + percent + "%" }
        if (percent <= 15) return { code: "WRN", text: "LOW · " + percent + "%" }
        return { code: "NOM", text: "ON BATTERY · " + percent + "%" }
    }

    // --- UPower Battery Reference ---
    readonly property var battery: UPower.displayDevice
    property int percent: battery && battery.ready
        ? Math.max(0, Math.min(100, Math.round(battery.percentage * 100)))
        : 0
    // Plugged in is not charging: a charge limit (e.g. 70%) holds the battery on AC.
    readonly property bool onAc: !!(battery && battery.ready && !UPower.onBattery)
    readonly property bool isCharging: !!(battery && battery.ready && battery.state === UPowerDeviceState.Charging)
    readonly property bool full: onAc && (battery.state === UPowerDeviceState.FullyCharged || percent >= 99)
    readonly property bool holding: onAc && !isCharging && !full
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
            "bat=; for b in /sys/class/power_supply/BAT*; do [ -d \"$b\" ] && { bat=$b; break; }; done",
            "rd \"$bat/cycle_count\"; cycles=$REPLY",
            "rd \"$bat/charge_full\"; c_full=$REPLY",
            "rd \"$bat/charge_full_design\"; c_des=$REPLY",
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

    component StatBar: Column {
        id: bar
        property string label
        property var value
        property int percent
        spacing: 6

        StatRow {
            width: bar.width
            label: bar.label
            value: bar.value
        }
        CnTicks {
            width: bar.width
            value: bar.percent
        }
    }

    // --- System telemetry ---
    Column {
        id: systemSection
        anchors.top: root.header.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 14

        // CPU temperature has no percentage scale, so it stays above the bars.
        StatRow {
            width: parent.width
            label: "CPU TEMP"
            value: root.cpuTemp > 0 ? (root.cpuTemp + "°C") : "--°C"
            valueColor: root.cpuTemp >= 80 ? Hud.alert : Hud.cnInk
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

    HudDivider {
        id: div2
        anchors.top: systemSection.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
    }

    Text {
        id: batteryTitle
        anchors.top: div2.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.leftMargin: 16
        text: "PWR · TELEMETRY"
        color: Hud.cnTextMuted
        font.family: Hud.mono
        font.pixelSize: 9
        font.letterSpacing: 1.0
    }

    HudSummary {
        anchors.top: batteryTitle.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        headline: root.full ? "FULL (AC)"
                  : root.isCharging ? "CHARGING"
                  : root.holding ? "ON AC · HOLD" : "DISCHARGING"
        value: (root.isCharging ? "+" : "") + root.percent + "%"
        valueColor: root.percent <= 15 ? Hud.alert : Hud.cnInk
        caption: root.full ? "FULLY CHARGED"
                 : root.isCharging ? "TO FULL  " + root.formatSeconds(root.timeToFull)
                 : root.holding ? "CHARGE LIMIT REACHED"
                 : "REMAINING  " + root.formatSeconds(root.timeToEmpty)
        rows: [
            { label: "POWER", value: root.energyRate > 0 ? root.energyRate.toFixed(1) + " W" : "-- W" },
            { label: "HEALTH", value: root.batteryHealth > 0 ? root.batteryHealth + "%" : "--" },
            { label: "CYCLES", value: root.cycleCount > 0 ? root.cycleCount : "--" }
        ]
    }
}
