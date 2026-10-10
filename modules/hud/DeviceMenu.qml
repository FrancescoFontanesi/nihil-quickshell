import "../common"
import QtQuick 2.12
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth

// Wi-Fi / Bluetooth side drawer. LockHud places it in its controls and drives it.
Rectangle {
    id: deviceMenu

    property PanelWindow panelWindow
    property bool hudOpen: false
    signal systemChanged()

    width: menu !== "" ? devicePanelWidth : 0
    visible: width > 0
    color: Hud.panelBg
    border.width: 1
    border.color: Hud.borderPassive
    clip: true

    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    // ======== STATE ========
    property int devicePanelWidth: 300
    property string menu: ""
    property string listFilter: "available"
    property string wifiConnectingId: ""
    property string connectionError: ""
    property bool wifiEnabled: true
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothEnabled: !!btAdapter && btAdapter.enabled
    property var pendingPair: null
    property var savedConnections: []
    property var savedUuids: ({})
    property var savedWifiEntries: []
    property var wifiEntries: []
    readonly property var bluetoothEntries: btAdapter ? btAdapter.devices.values.filter(function(d) {
        // BlueZ falls back to the address as the alias when a device has no name.
        return d.paired || d.connected || d.name.replace(/-/g, ":").toUpperCase() !== d.address.toUpperCase()
    }).sort(function(a, b) {
        if (a.connected !== b.connected) return a.connected ? -1 : 1
        if (a.paired !== b.paired) return a.paired ? -1 : 1
        return a.name.localeCompare(b.name)
    }) : []
    readonly property var pairedBluetoothEntries: bluetoothEntries.filter(function(d) { return d.paired }).sort(function(a, b) {
        if (a.connected !== b.connected) return a.connected ? -1 : 1
        return a.name.localeCompare(b.name)
    })
    property var selectedWifi: null
    property string wifiPasswordInput: ""

    function updateKeyboardFocus() {
        if (!panelWindow) return
        if (deviceMenu.hudOpen && deviceMenu.menu === "wifi" && deviceMenu.selectedWifi !== null) {
            panelWindow.focusable = true
            if (panelWindow.WlrLayershell)
                panelWindow.WlrLayershell.keyboardFocus = WlrKeyboardFocus.Exclusive
            Qt.callLater(function() {
                if (passwordInput) {
                    passwordInput.forceActiveFocus()
                }
            })
        } else {
            if (panelWindow.WlrLayershell)
                panelWindow.WlrLayershell.keyboardFocus = WlrKeyboardFocus.None
            panelWindow.focusable = false
        }
    }

    function clearWifiSelection() {
        selectedWifi = null
        wifiPasswordInput = ""
    }

    onSelectedWifiChanged: updateKeyboardFocus()
    onMenuChanged: {
        if (menu !== "bluetooth" && btAdapter)
            btAdapter.discovering = false
        if (menu === "")
            clearWifiSelection()
        updateKeyboardFocus()
    }
    onHudOpenChanged: {
        if (!hudOpen)
            clearWifiSelection()
        updateKeyboardFocus()
    }

    function open(name) {
        if (menu === name) {
            menu = ""
            clearWifiSelection()
            return
        }

        menu = name
        listFilter = "available"
        connectionError = ""
        clearWifiSelection()
        refresh()
        if (name === "bluetooth" && bluetoothEnabled)
            btAdapter.discovering = true
    }

    function refresh() {
        if (menu === "wifi") {
            restartProc(savedConnScan)
            restartProc(wifiScan)
        }
    }

    function togglePower() {
        if (menu === "wifi") {
            if (wifiAction.running) return
            wifiEnabled = !wifiEnabled
            runWifiCommand(["nmcli", "radio", "wifi", wifiEnabled ? "on" : "off"])
            if (!wifiEnabled) {
                wifiEntries = []
                savedWifiEntries = []
            }
        } else {
            if (btAdapter) {
                var on = !btAdapter.enabled
                btAdapter.enabled = on
                btAdapter.discovering = on && menu === "bluetooth"
            }
        }
    }

    function restartProc(p) {
        p.running = false
        p.running = true
    }
    function runWifiCommand(command, id) {
        if (wifiAction.running) return false
        connectionError = ""
        wifiConnectingId = id || ""
        wifiAction.command = command
        wifiAction.running = true
        return true
    }
    function updateSavedWifiEntries() {
        var map = Object.create(null)
        for (var i = 0; i < wifiEntries.length; ++i) {
            wifiEntries[i].isSaved = savedConnections.indexOf(wifiEntries[i].ssid) !== -1
            map[wifiEntries[i].ssid] = wifiEntries[i]
        }
        wifiEntries = wifiEntries.slice()
        var list = []
        for (var j = 0; j < savedConnections.length; ++j) {
            var ssid = savedConnections[j]
            if (map[ssid]) {
                list.push(map[ssid])
            } else {
                list.push({
                    ssid: ssid,
                    inUse: false,
                    security: "WPA2",
                    isSecured: true,
                    isSaved: true,
                    signal: 0
                })
            }
        }
        list.sort(function(a, b) {
            if (a.inUse !== b.inUse) return a.inUse ? -1 : 1
            return b.signal - a.signal
        })
        savedWifiEntries = list
    }

    function parseWifiEntries(output) {
        var entries = []
        var seen = Object.create(null)
        var lines = output.trim().split("\n")
        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i].trim()
            if (!line) continue
            var inUse = line.charAt(0) === '*'
            var rest = line.substring(line.indexOf(':') + 1)
            var parts = rest.split(':')
            if (parts.length < 3) continue
            var signal = parts[parts.length - 1]
            var security = parts[parts.length - 2]
            var ssid = parts.slice(0, parts.length - 2).join(':')
            if (!ssid || ssid.length === 0) continue

            if (inUse && ssid === deviceMenu.wifiConnectingId) {
                deviceMenu.wifiConnectingId = ""
            }

            var isSecured = security !== "" && security !== "--"
            if (seen[ssid]) {
                var existing = seen[ssid]
                var level = parseInt(signal) || 0
                if (inUse || (!existing.inUse && level > existing.signal)) {
                    existing.signal = level
                    existing.security = security
                    existing.isSecured = isSecured
                }
                existing.inUse = existing.inUse || inUse
                continue
            }
            var isSaved = deviceMenu.savedConnections.indexOf(ssid) !== -1
            var entry = {
                ssid: ssid,
                inUse: inUse,
                security: security,
                isSecured: isSecured,
                isSaved: isSaved,
                signal: parseInt(signal) || 0
            }
            seen[ssid] = entry
            entries.push(entry)
        }
        entries.sort(function(a, b) {
            if (a.inUse !== b.inUse) return a.inUse ? -1 : 1
            if (a.isSaved !== b.isSaved) return a.isSaved ? -1 : 1
            return b.signal - a.signal
        })
        return entries
    }

    // Prefer the profile UUID: the profile name can differ from the SSID.
    function savedConnCommand(action, ssid) {
        var uuid = savedUuids[ssid]
        return uuid ? ["nmcli", "connection", action, "uuid", uuid]
                    : ["nmcli", "connection", action, "id", ssid]
    }

    function connectWifi(item, password) {
        if (!item) return
        if (item.inUse && (!password || password.length === 0)) {
            runWifiCommand(savedConnCommand("down", item.ssid), item.ssid)
            return
        }

        if (password && password.length > 0) {
            // shortcut: the password is visible in nmcli's argv while it runs; switch to a passwd-file if this machine becomes multi-user
            if (runWifiCommand(["nmcli", "device", "wifi", "connect", item.ssid, "password", password], item.ssid))
                deviceMenu.clearWifiSelection()
            return
        }

        if (item.isSaved || !item.isSecured) {
            runWifiCommand(["nmcli", "device", "wifi", "connect", item.ssid], item.ssid)
            return
        }

        deviceMenu.selectedWifi = item
        deviceMenu.wifiPasswordInput = ""
    }

    function forgetWifi(ssid) {
        if (!ssid) return
        if (!runWifiCommand(savedConnCommand("delete", ssid))) return
        var nextSaved = []
        for (var i = 0; i < savedConnections.length; ++i) {
            if (savedConnections[i] !== ssid) nextSaved.push(savedConnections[i])
        }
        savedConnections = nextSaved
        updateSavedWifiEntries()
    }

    function toggleBluetoothDevice(item) {
        if (!item) return
        connectionError = ""
        if (item.connected) {
            item.disconnect()
        } else if (!item.paired) {
            item.trusted = true
            deviceMenu.pendingPair = item
            item.pair()
        } else {
            item.connect()
        }
    }

    // Pairing is async: once paired, connect; if it failed, report it.
    Connections {
        target: deviceMenu.pendingPair
        ignoreUnknownSignals: true
        function onPairedChanged() {
            if (target.paired) {
                target.connect()
                deviceMenu.pendingPair = null
            }
        }
        function onPairingChanged() {
            if (!target.pairing && !target.paired) {
                deviceMenu.pendingPair = null
                if (deviceMenu.menu === "bluetooth")
                    deviceMenu.connectionError = "// PAIRING FAILED"
            }
        }
    }
    Process {
        id: savedConnScan
        command: ["bash", "-c", "nmcli -t -f UUID,TYPE connection show | while IFS=: read -r u t; do [ \"$t\" = 802-11-wireless ] && printf '%s\\t%s\\n' \"$u\" \"$(nmcli -g 802-11-wireless.ssid connection show \"$u\")\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                // One "uuid<TAB>ssid" line per Wi-Fi profile; key by SSID, not profile name.
                var lines = text.trim().split("\n")
                var saved = []
                var uuids = ({})
                for (var i = 0; i < lines.length; ++i) {
                    var parts = lines[i].split("\t")
                    if (parts.length < 2) continue
                    var ssid = parts[1].trim()
                    if (!ssid || ssid === "-") continue
                    if (saved.indexOf(ssid) === -1) saved.push(ssid)
                    uuids[ssid] = parts[0].trim()
                }
                deviceMenu.savedConnections = saved
                deviceMenu.savedUuids = uuids
                deviceMenu.updateSavedWifiEntries()
            }
        }
    }

    Process {
        id: wifiScan
        command: ["nmcli", "-e", "no", "-t", "-f", "IN-USE,SSID,SECURITY,SIGNAL", "device", "wifi", "list", "--rescan", "auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                deviceMenu.wifiEntries = deviceMenu.parseWifiEntries(text)
                deviceMenu.updateSavedWifiEntries()
            }
        }
    }

    Process {
        id: wifiAction
        onExited: (exitCode) => {
            deviceMenu.wifiConnectingId = ""
            if (deviceMenu.menu === "wifi")
                deviceMenu.connectionError = exitCode === 0 ? "" : "// WI-FI ACTION FAILED"
            wifiAction.command = []
            if (deviceMenu.menu === "wifi") deviceMenu.refresh()
            deviceMenu.systemChanged()
        }
    }
    component FilterTab: Rectangle {
        id: tab
        required property string filterKey
        required property string label
        height: 26
        color: deviceMenu.listFilter === tab.filterKey ? Hud.surfaceInactive : (tabMouse.containsMouse ? "#14171c" : Hud.bgRaised)
        border.width: 1
        border.color: deviceMenu.listFilter === tab.filterKey ? Hud.fg : (tabMouse.containsMouse ? Hud.borderSecondary : Hud.borderPassive)

        Text {
            anchors.centerIn: parent
            text: tab.label
            color: deviceMenu.listFilter === tab.filterKey ? Hud.fg : (tabMouse.containsMouse ? Hud.textSecondary : "#6c737d")
            font.family: Hud.font
            font.pixelSize: 9
            font.bold: deviceMenu.listFilter === tab.filterKey
            font.letterSpacing: 0.8
        }

        MouseArea {
            id: tabMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: deviceMenu.listFilter = tab.filterKey
        }
    }

    component PanelButton: Rectangle {
        id: btn
        required property string label
        required property color baseColor
        required property color hoverColor
        required property color borderColor
        required property color textColor
        property bool textBold: false
        signal clicked()

        height: 30
        color: btn.baseColor
        border.width: 1
        border.color: btn.borderColor

        Text {
            anchors.centerIn: parent
            text: btn.label
            color: btn.textColor
            font.family: Hud.font
            font.pixelSize: 10
            font.bold: btn.textBold
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: parent.color = btn.hoverColor
            onExited: parent.color = btn.baseColor
            onClicked: btn.clicked()
        }
    }

    // Header
    Item {
        x: 14
        y: 18
        width: parent.width - 28
        height: 48

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            width: parent.width - deviceSwitch.width - 8
            text: deviceMenu.menu === "wifi" ? "// NETWORKS // WIRELESS" : "// DEVICES // BLUETOOTH"
            color: Hud.textPrimary
            font.family: Hud.font
            font.pixelSize: 12
            font.bold: true
            font.letterSpacing: 1.5
            elide: Text.ElideRight
        }

        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            width: parent.width - deviceSwitch.width - 8
            text: deviceMenu.menu === "wifi"
                  ? (deviceMenu.connectionError || (deviceMenu.wifiEnabled ? ":: SCAN: ACTIVE" : ":: RADIO: OFF"))
                  : (deviceMenu.connectionError || (deviceMenu.btAdapter && deviceMenu.btAdapter.discovering ? ":: SCAN: ACTIVE" : (deviceMenu.bluetoothEnabled ? ":: CONTROLLER: ON" : ":: CONTROLLER: OFF")))
            color: Hud.textMuted
            font.family: Hud.font
            font.pixelSize: 9
            font.letterSpacing: 1.0
            elide: Text.ElideRight
        }

        // Switch toggle ON/OFF
        Rectangle {
            id: deviceSwitch
            property bool active: deviceMenu.menu === "wifi" ? deviceMenu.wifiEnabled : deviceMenu.bluetoothEnabled
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 20
            color: "transparent"
            border.width: 1
            border.color: active ? Hud.fg : Hud.borderSecondary

            Rectangle {
                width: 18
                height: parent.height - 4
                y: 2
                x: deviceSwitch.active ? parent.width - width - 2 : 2
                color: deviceSwitch.active ? Hud.fg : Hud.textGhost
                Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: deviceMenu.togglePower()
            }
        }
    }

    Rectangle {
        x: 12
        y: 72
        width: parent.width - 24
        height: 1
        color: Hud.borderPassive
    }

    // Device filter tabs: available | saved/paired
    Row {
        x: 12
        y: 80
        width: parent.width - 24
        height: 26
        spacing: 6

        FilterTab {
            id: tabAvailable
            width: Math.floor((parent.width - 6) / 2)
            filterKey: "available"
            label: "[ AVAILABLE ]"
        }

        FilterTab {
            width: parent.width - tabAvailable.width - 6
            filterKey: "saved"
            label: deviceMenu.menu === "wifi" ? "[ SAVED ]" : "[ PAIRED ]"
        }
    }

    // Wi-Fi password entry
    Item {
        id: authView
        visible: deviceMenu.menu === "wifi" && deviceMenu.selectedWifi !== null
        x: 12
        y: 114
        width: parent.width - 24
        height: 146

        Rectangle {
            anchors.fill: parent
            color: Hud.bgRaised
            border.width: 1
            border.color: Hud.borderSecondary
        }

        Text {
            x: 12; y: 12
            text: "// AUTH REQUIRED"
            color: Hud.fg
            font.family: Hud.font
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 1.2
        }

        Text {
            x: 12; y: 30
            width: parent.width - 24
            text: "SSID: " + (deviceMenu.selectedWifi ? deviceMenu.selectedWifi.ssid : "")
            color: Hud.textMuted
            font.family: Hud.font
            font.pixelSize: 10
            elide: Text.ElideRight
        }

        Rectangle {
            x: 12; y: 52
            width: parent.width - 24
            height: 32
            color: "#050607"
            border.width: 1
            border.color: passwordInput.activeFocus ? Hud.fg : Hud.borderPassive

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: ">"
                color: Hud.textMuted
                font.family: Hud.font
                font.pixelSize: 12
            }

            TextInput {
                id: passwordInput
                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: deviceMenu.wifiPasswordInput
                echoMode: TextInput.Password
                color: Hud.fg
                font.family: Hud.font
                font.pixelSize: 12
                activeFocusOnTab: true
                onTextChanged: deviceMenu.wifiPasswordInput = text
                onAccepted: deviceMenu.connectWifi(deviceMenu.selectedWifi, text)
                Keys.onEscapePressed: deviceMenu.clearWifiSelection()
            }
        }

        Row {
            x: 12; y: 98
            spacing: 8
            width: parent.width - 24

            PanelButton {
                width: (parent.width - 8) / 2
                label: "[ CONNECT ]"
                baseColor: Hud.surfaceInactive
                hoverColor: "#34383e"
                borderColor: Hud.fg
                textColor: Hud.fg
                textBold: true
                onClicked: deviceMenu.connectWifi(deviceMenu.selectedWifi, deviceMenu.wifiPasswordInput)
            }

            PanelButton {
                width: (parent.width - 8) / 2
                label: "[ CANCEL ]"
                baseColor: "#111318"
                hoverColor: Hud.surfaceInactive
                borderColor: Hud.borderSecondary
                textColor: Hud.textMuted
                onClicked: deviceMenu.clearWifiSelection()
            }
        }
    }

    // Network/device list with status highlighting
    ListView {
        id: deviceList
        visible: !(deviceMenu.menu === "wifi" && deviceMenu.selectedWifi !== null)
        x: 12
        y: 114
        width: parent.width - 24
        height: parent.height - 128
        clip: true
        spacing: 4
        model: deviceMenu.menu === "wifi"
               ? (deviceMenu.listFilter === "available" ? deviceMenu.wifiEntries : deviceMenu.savedWifiEntries)
               : (deviceMenu.listFilter === "available" ? deviceMenu.bluetoothEntries : deviceMenu.pairedBluetoothEntries)

        Item {
            anchors.fill: parent
            visible: deviceList.count === 0

            Text {
                anchors.centerIn: parent
                text: deviceMenu.menu === "bluetooth" && deviceMenu.btAdapter && deviceMenu.btAdapter.discovering
                      ? "// SCANNING..."
                      : (deviceMenu.listFilter === "available" ? "// NO RESULTS" : "// NO SAVED ITEMS")
                color: Hud.textGhost
                font.family: Hud.font
                font.pixelSize: 10
                font.letterSpacing: 1.0
            }
        }

        delegate: Rectangle {
            id: delegateRoot
            required property var modelData
            readonly property bool isConnected: deviceMenu.menu === "wifi" ? Boolean(modelData.inUse) : Boolean(modelData.connected)
            readonly property bool isSaved: deviceMenu.menu === "wifi" ? Boolean(modelData.isSaved) : Boolean(modelData.paired)
            readonly property bool isConnecting: deviceMenu.menu === "wifi"
                                                ? deviceMenu.wifiConnectingId !== "" && modelData.ssid === deviceMenu.wifiConnectingId
                                                : Boolean(modelData.pairing || modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting)

            width: deviceList.width
            height: 50
            color: isConnected ? Hud.surfaceInactive : (isConnecting ? "#161b22" : (rowMouse.containsMouse ? "#15181d" : Hud.bgRaised))
            border.width: 1
            border.color: isConnected ? Hud.fg : (isConnecting ? Hud.dim : (rowMouse.containsMouse ? Hud.borderSecondary : Hud.borderPassive))
            clip: true

            // Laser scanline sweep feedback when connecting
            Rectangle {
                visible: delegateRoot.isConnecting
                width: 2
                height: parent.height
                color: Hud.fg
                opacity: 0.8
                z: 1

                SequentialAnimation on x {
                    running: delegateRoot.isConnecting
                    loops: Animation.Infinite
                    NumberAnimation { from: 0; to: delegateRoot.width - 2; duration: 750; easing.type: Easing.Linear }
                    NumberAnimation { from: delegateRoot.width - 2; to: 0; duration: 750; easing.type: Easing.Linear }
                }
            }

            // Row MouseArea for click selection/connection
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    if (deviceMenu.menu === "wifi") {
                        if (modelData.inUse || modelData.isSaved || !modelData.isSecured) {
                            deviceMenu.connectWifi(modelData, "")
                        } else {
                            deviceMenu.selectedWifi = modelData
                            deviceMenu.wifiPasswordInput = ""
                        }
                    } else {
                        deviceMenu.toggleBluetoothDevice(modelData)
                    }
                }
            }

            // Foreground container (z: 5) so child action buttons receive direct clicks
            Item {
                anchors.fill: parent
                anchors.margins: 8
                z: 5

                Rectangle {
                    id: statusDot
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.topMargin: 5
                    width: 6
                    height: 6
                    radius: 0
                    color: delegateRoot.isConnected ? Hud.fg : (delegateRoot.isConnecting ? Hud.fg : (delegateRoot.isSaved ? Hud.textMuted : "#34383e"))

                    SequentialAnimation on opacity {
                        running: delegateRoot.isConnecting
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.3; to: 1.0; duration: 300 }
                        NumberAnimation { from: 1.0; to: 0.3; duration: 300 }
                    }
                }

                Text {
                    anchors.left: statusDot.right
                    anchors.leftMargin: 8
                    anchors.top: parent.top
                    anchors.right: actionControls.left
                    anchors.rightMargin: 8
                    text: deviceMenu.menu === "wifi" ? modelData.ssid : modelData.name
                    color: delegateRoot.isConnected ? Hud.fg : (delegateRoot.isConnecting ? Hud.fg : Hud.textSecondary)
                    font.family: Hud.font
                    font.pixelSize: 11
                    font.bold: delegateRoot.isConnected || delegateRoot.isConnecting
                    elide: Text.ElideRight
                }

                Text {
                    anchors.left: statusDot.right
                    anchors.leftMargin: 8
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    anchors.right: actionControls.left
                    anchors.rightMargin: 8
                    text: {
                        if (deviceMenu.menu === "wifi") {
                            var sec = modelData.isSecured ? "[SEC] " : "[OPEN] "
                            var sig = modelData.signal > 0 ? (modelData.signal + "%") : "[OFFLINE]"
                            return sec + sig
                        }
                        return modelData.address
                    }
                    color: delegateRoot.isConnected ? Hud.textMuted : Hud.textGhost
                    font.family: Hud.font
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }

                Row {
                    id: actionControls
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    // Password prompt button (Wi-Fi secured networks)
                    HudButton {
                        visible: deviceMenu.menu === "wifi" && modelData.isSecured
                        boxSize: 22
                        glyph: "PW"
                        glyphSize: 8
                        onClicked: {
                            deviceMenu.selectedWifi = modelData
                            deviceMenu.wifiPasswordInput = ""
                        }
                    }

                    // Forget button (saved Wi-Fi or paired Bluetooth)
                    HudButton {
                        visible: delegateRoot.isSaved
                        boxSize: 22
                        glyph: "✕"
                        glyphSize: 11
                        hoverBg: "#3a1414"
                        hoverBorder: Hud.alert
                        idleText: Hud.dim
                        hoverText: Hud.alert
                        onClicked: {
                            if (deviceMenu.menu === "wifi") {
                                deviceMenu.forgetWifi(modelData.ssid)
                            } else {
                                modelData.forget()
                            }
                        }
                    }

                    // Status badge / Action label
                    Rectangle {
                        width: badgeLabel.width + 10
                        height: 22
                        color: delegateRoot.isConnected ? Hud.fg : (delegateRoot.isConnecting ? Hud.borderPassive : "transparent")
                        border.width: 1
                        border.color: delegateRoot.isConnected ? Hud.fg : (delegateRoot.isConnecting ? Hud.fg : Hud.borderSecondary)

                        Text {
                            id: badgeLabel
                            anchors.centerIn: parent
                            text: {
                                if (delegateRoot.isConnecting) return "SYNC..."
                                if (delegateRoot.isConnected) return "ACTIVE"
                                if (deviceMenu.menu === "wifi") {
                                    if (modelData.isSaved) return "SAVED"
                                    return modelData.isSecured ? "LOCK" : "JOIN"
                                }
                                return modelData.paired ? "PAIRED" : "LINK"
                            }
                            color: delegateRoot.isConnected ? "#000000" : (delegateRoot.isConnecting ? Hud.fg : Hud.textMuted)
                            font.family: Hud.font
                            font.pixelSize: 8
                            font.bold: delegateRoot.isConnected || delegateRoot.isConnecting
                            font.letterSpacing: 0.8
                        }

                        SequentialAnimation on opacity {
                            running: delegateRoot.isConnecting
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.4; to: 1.0; duration: 300 }
                            NumberAnimation { from: 1.0; to: 0.4; duration: 300 }
                        }
                    }
                }
            }
        }
    }
}
