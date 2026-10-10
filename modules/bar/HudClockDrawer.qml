import "../common"
import QtQuick 2.15
import Quickshell.Io

HudDrawer {
    id: root
    code: open ? "CAL · " + Qt.formatDate(new Date(), "yyyy-MM-dd") : ""  // re-read on every open
    title: "CALENDAR & WEATHER"
    statusCode: weatherStatus().code
    statusText: weatherStatus().text

    function weatherStatus() {
        if (weatherLoading) return { code: "LDG", text: "FETCHING WEATHER" }
        if (weatherDesc === "DATA UNAVAILABLE") return { code: "ERR", text: "WEATHER UNAVAILABLE" }
        if (weatherDesc === "AWAITING DATA") return { code: "IDL", text: "AWAITING DATA" }
        return { code: "NOM", text: weatherCity }
    }

    // --- Weather State ---
    property string weatherCity: "DETECTING..."
    property string weatherTemp: "--°C"
    property string weatherDesc: "AWAITING DATA"
    property string weatherHumidity: "--%"
    property string weatherWind: "-- km/h"
    property string weatherPrecip: "-- mm"
    property bool weatherLoading: false

    Process {
        id: weatherProcess
        command: ["curl", "-fsL", "--max-time", "4", "https://wttr.in/?format=j1"]
        onExited: (exitCode) => {
            root.weatherLoading = false
            if (exitCode !== 0)
                root.markWeatherUnavailable()
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    if (data && data.current_condition && data.current_condition.length > 0) {
                        var cur = data.current_condition[0]
                        var area = (data.nearest_area && data.nearest_area.length > 0) ? data.nearest_area[0] : null
                        var cityName = area && area.areaName && area.areaName[0] ? area.areaName[0].value : "CURRENT LOCATION"
                        var country = area && area.country && area.country[0] ? area.country[0].value : ""
                        root.weatherCity = (country.length > 0 ? (cityName + ", " + country) : cityName).toUpperCase()
                        root.weatherTemp = (cur.temp_C ? (parseInt(cur.temp_C) > 0 ? "+" : "") + cur.temp_C + "°C" : "--°C")
                        root.weatherDesc = cur.weatherDesc && cur.weatherDesc[0] ? cur.weatherDesc[0].value.toUpperCase() : "CLEAR"
                        root.weatherHumidity = (cur.humidity || "--") + "%"
                        root.weatherWind = (cur.windspeedKmph || "--") + " km/h"
                        root.weatherPrecip = (cur.precipMM || "0") + " mm"
                    } else {
                        root.markWeatherUnavailable()
                    }
                } catch(e) {
                    root.markWeatherUnavailable()
                }
            }
        }
    }

    // Clears stale readings so the error is not shown next to old values
    function markWeatherUnavailable() {
        weatherDesc = "DATA UNAVAILABLE"
        weatherTemp = "--°C"
        weatherHumidity = "--%"
        weatherWind = "-- km/h"
        weatherPrecip = "-- mm"
    }

    function refreshWeather() {
        if (weatherLoading) return
        weatherLoading = true
        weatherProcess.running = true
    }

    Timer {
        id: weatherTimer
        interval: 1200000 // 20 minutes
        repeat: true
        running: root.open
        onTriggered: root.refreshWeather()
    }

    onOpenChanged: {
        if (open) {
            refreshWeather()
            displayedDate = new Date()
        }
    }

    // --- Calendar State ---
    property var displayedDate: new Date()
    readonly property var dayNames: ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
    readonly property var monthNames: [
        "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE",
        "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"
    ]

    function changeMonth(delta) {
        var d = new Date(displayedDate.getFullYear(), displayedDate.getMonth() + delta, 1)
        displayedDate = d
    }

    function generateCalendarDays(year, month) {
        var firstDay = new Date(year, month, 1)
        var startingDay = (firstDay.getDay() + 6) % 7 // Monday = 0
        var daysInMonth = new Date(year, month + 1, 0).getDate()
        var daysInPrevMonth = new Date(year, month, 0).getDate()
        var today = new Date()
        var isCurrentMonth = (today.getFullYear() === year && today.getMonth() === month)

        var list = []
        for (var i = startingDay - 1; i >= 0; i--) {
            list.push({
                dayNumber: daysInPrevMonth - i,
                isCurrentMonth: false,
                isToday: false
            })
        }
        for (var d = 1; d <= daysInMonth; d++) {
            list.push({
                dayNumber: d,
                isCurrentMonth: true,
                isToday: isCurrentMonth && (today.getDate() === d)
            })
        }
        var remaining = 42 - list.length
        for (var n = 1; n <= remaining; n++) {
            list.push({
                dayNumber: n,
                isCurrentMonth: false,
                isToday: false
            })
        }
        return list
    }

    property var calendarDays: generateCalendarDays(displayedDate.getFullYear(), displayedDate.getMonth())

    // --- Weather Section ---
    HudSummary {
        id: weatherSection
        anchors.top: root.header.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        headline: root.weatherCity
        value: root.weatherTemp
        caption: root.weatherDesc
        rows: [
            { label: "HUMIDITY", value: root.weatherHumidity },
            { label: "WIND", value: root.weatherWind },
            { label: "PRECIP", value: root.weatherPrecip }
        ]
    }

    HudDivider {
        id: div2
        anchors.top: weatherSection.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
    }

    // --- Calendar Section ---
    Item {
        id: calendarSection
        anchors.top: div2.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 16

        // Month navigation bar
        Item {
            id: monthNav
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 22

            CnButton {
                anchors.left: parent.left
                width: 22
                height: 22
                cut: 4
                text: "<"
                textSize: 11
                onClicked: root.changeMonth(-1)
            }

            Text {
                anchors.centerIn: parent
                text: root.monthNames[root.displayedDate.getMonth()] + " " + root.displayedDate.getFullYear()
                color: Hud.cnInk
                font.family: Hud.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
            }

            CnButton {
                anchors.right: parent.right
                width: 22
                height: 22
                cut: 4
                text: ">"
                textSize: 11
                onClicked: root.changeMonth(1)
            }
        }

        // Days of week header
        Row {
            id: daysHeader
            anchors.top: monthNav.bottom
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.floor(calendarSection.width / 7) * 7
            height: 20

            Repeater {
                model: root.dayNames
                delegate: Item {
                    width: daysHeader.width / 7
                    height: parent.height

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: Hud.cnTextMuted
                        font.family: Hud.mono
                        font.pixelSize: 9
                        font.letterSpacing: 0.9
                    }
                }
            }
        }

        // 42-cells Grid
        Grid {
            id: calendarGrid
            anchors.top: daysHeader.bottom
            anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: daysHeader.width
            columns: 7
            spacing: 0

            Repeater {
                model: root.calendarDays
                delegate: Item {
                    required property var modelData
                    width: calendarGrid.width / 7
                    height: calendarGrid.height / 6

                    // Today is an inverted cell; hover outlines the others.
                    CnCut {
                        anchors.fill: parent
                        anchors.margins: 2
                        br: 4
                        fill: modelData.isToday ? Hud.cnInk : "transparent"
                        edge: cellMouse.containsMouse && !modelData.isToday ? Hud.cnInk : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.dayNumber
                        color: modelData.isToday ? Hud.cnGround
                              : (modelData.isCurrentMonth ? Hud.cnInk : Hud.cnBorderActive)
                        font.family: Hud.mono
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
            }
        }
    }
}
