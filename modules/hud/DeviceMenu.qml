import "../common"
import QtQuick
import Quickshell
import Quickshell.Wayland

// Wi-Fi / Bluetooth side drawer. LockHud places it in its controls and drives it.
// WifiModel and BluetoothModel own the system state; this file is the view and the password step.
Rectangle {
    id: deviceMenu

    property PanelWindow panelWindow
    property bool hudOpen: false
    signal systemChanged()

    // ======== STATE ========
    property int devicePanelWidth: 300
    readonly property int contentWidth: devicePanelWidth - 32
    property string menu: ""                 // "" | "wifi" | "bluetooth"
    property string listFilter: "available"  // "available" | "saved"
    property var authNet: null               // network awaiting a passphrase
    property bool showPassword: false
    readonly property bool isWifi: menu === "wifi"
    readonly property bool authOpen: menu === "wifi" && authNet !== null
    property alias wifi: wifiModel
    property alias bluetooth: btModel

    width: menu !== "" ? devicePanelWidth : 0
    visible: width > 0
    color: Hud.cnGround
    border.width: 1
    border.color: Hud.cnBorderPassive
    clip: true

    Behavior on width { CnAnim { duration: Hud.durMedium } }

    WifiModel {
        id: wifiModel
        active: deviceMenu.hudOpen && deviceMenu.menu === "wifi"
        onRadioChanged: deviceMenu.systemChanged()
        onPasswordRequired: (net) => deviceMenu.askPassword(net)
    }

    BluetoothModel {
        id: btModel
        active: deviceMenu.hudOpen && deviceMenu.menu === "bluetooth"
    }

    // ======== FUNCTIONS ========
    function open(name) {
        if (menu === name) {
            menu = ""
            return
        }
        menu = name
        listFilter = "available"
        wifi.clearError()
        bluetooth.clearError()
        authNet = null
    }

    function refresh() {
        wifi.refresh(false)
    }

    function askPassword(net) {
        authNet = net
        showPassword = false
        passField.text = ""
    }

    function cancelAuth() {
        authNet = null
    }

    function submitAuth() {
        if (authNet === null) return
        wifi.connectWithPassword(authNet, passField.text)
        authNet = null
    }

    function updateKeyboardFocus() {
        if (!panelWindow) return
        if (deviceMenu.hudOpen && deviceMenu.menu === "wifi" && deviceMenu.authNet !== null) {
            panelWindow.focusable = true
            if (panelWindow.WlrLayershell)
                panelWindow.WlrLayershell.keyboardFocus = WlrKeyboardFocus.Exclusive
            Qt.callLater(function() { passField.input.forceActiveFocus() })
        } else {
            if (panelWindow.WlrLayershell)
                panelWindow.WlrLayershell.keyboardFocus = WlrKeyboardFocus.None
            panelWindow.focusable = false
        }
    }

    // Status strip: one code and one line of text for the active menu.
    readonly property var status: menu === "bluetooth" ? btStatus() : wifiStatus()

    function wifiStatus() {
        if (wifi.error !== "") return { code: "ERR", text: wifi.error + " · " + wifi.errorSsid }
        if (!wifi.enabled) return { code: "OFF", text: "RADIO OFF" }
        if (wifi.connectingSsid !== "") return { code: "LDG", text: "CONNECTING · " + wifi.connectingSsid }
        if (wifi.busy) return { code: "LDG", text: "WORKING" }
        if (wifi.scanning) return { code: "LDG", text: "SCANNING" }
        if (wifi.activeSsid !== "") return { code: "NOM", text: wifi.activeSsid }
        return { code: "IDL", text: "NOT CONNECTED" }
    }

    function btStatus() {
        if (!bluetooth.available) return { code: "OFF", text: "NO ADAPTER" }
        if (bluetooth.error !== "")
            return { code: "ERR", text: bluetooth.error + " · " + (bluetooth.errorDevice ? bluetooth.errorDevice.name : "") }
        if (!bluetooth.enabled) return { code: "OFF", text: "CONTROLLER OFF" }
        if (bluetooth.pending) return { code: "LDG", text: bluetooth.pendingKind.toUpperCase() + " · " + bluetooth.pending.name }
        if (bluetooth.discovering) return { code: "LDG", text: "SCANNING" }
        var n = bluetooth.devices.filter(function(d) { return d.connected }).length
        if (n > 0) return { code: "NOM", text: n + " CONNECTED" }
        return { code: "IDL", text: "IDLE" }
    }

    // Empty list: code line (mono) and an optional sentence hint.
    function emptyInfo() {
        var avail = listFilter === "available"
        if (isWifi) {
            if (!wifi.enabled) return { code: "RADIO OFF", hint: "Turn the radio on to scan." }
            if (wifi.scanning) return { code: "SCANNING", hint: "" }
            return avail ? { code: "NO NETWORKS IN RANGE", hint: "Press SCAN to search again." }
                         : { code: "NO SAVED NETWORKS", hint: "" }
        }
        if (!bluetooth.available) return { code: "NO ADAPTER", hint: "" }
        if (!bluetooth.enabled) return { code: "CONTROLLER OFF", hint: "Turn the controller on to scan." }
        if (bluetooth.discovering) return { code: "SCANNING", hint: "" }
        return avail ? { code: "NO DEVICES", hint: "Press SCAN to search again." }
                     : { code: "NO PAIRED DEVICES", hint: "" }
    }

    onMenuChanged: {
        if (menu === "") authNet = null
        if (menu !== "") enterAnim.restart()
        updateKeyboardFocus()
    }
    onHudOpenChanged: {
        if (!hudOpen) authNet = null
        updateKeyboardFocus()
    }
    onAuthNetChanged: updateKeyboardFocus()

    // ======== BODY ========
    // Fixed width: nothing reflows while the root animates its width.
    Item {
        id: body
        x: 16
        width: deviceMenu.contentWidth
        height: parent.height
        transform: Translate { id: bodyShift }

        // Panel displacement: content fades in and slides 16px into place.
        ParallelAnimation {
            id: enterAnim
            CnAnim { target: body; property: "opacity"; from: 0; to: 1; duration: 240 }
            CnAnim { target: bodyShift; property: "x"; from: 16; to: 0; duration: 240 }
        }

        // Header
        Text {
            x: 0; y: 16
            width: parent.width
            text: deviceMenu.isWifi
                  ? "NET · " + wifi.device.toUpperCase()
                  : "BT · " + (bluetooth.adapter ? String(bluetooth.adapter.adapterId).toUpperCase() : "NO ADAPTER")
            color: Hud.cnTextMuted
            font.family: Hud.mono
            font.pixelSize: 10
            font.letterSpacing: 1.2
            elide: Text.ElideRight
        }

        Text {
            id: title
            x: 0; y: 30
            text: deviceMenu.isWifi ? "WIRELESS" : "BLUETOOTH"
            color: Hud.cnInk
            font.family: Hud.font
            font.pixelSize: 22
            font.weight: Font.DemiBold
            font.letterSpacing: 0.44
        }

        CnSwitch {
            anchors.right: parent.right
            anchors.verticalCenter: title.verticalCenter
            width: implicitWidth
            checked: deviceMenu.isWifi ? wifi.enabled : bluetooth.enabled
            busy: !deviceMenu.isWifi && bluetooth.busy
            enabled: deviceMenu.isWifi ? !wifi.busy : bluetooth.available
            onToggled: {
                if (deviceMenu.isWifi) wifi.setEnabled(!wifi.enabled)
                else bluetooth.setEnabled(!bluetooth.enabled)
            }
        }

        // Status strip
        Item {
            id: statusStrip
            x: 0; y: 64
            width: parent.width
            height: 24

            CnStatus {
                id: statusMark
                anchors.verticalCenter: parent.verticalCenter
                width: implicitWidth
                code: deviceMenu.status.code
            }

            Text {
                anchors.left: statusMark.right
                anchors.leftMargin: 8
                anchors.right: scanBtn.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: deviceMenu.status.text
                color: Hud.cnTextSecondary
                font.family: Hud.mono
                font.pixelSize: 11
                font.letterSpacing: 0.66
                elide: Text.ElideRight
            }

            CnButton {
                id: scanBtn
                anchors.right: parent.right
                y: 0
                height: 24
                width: implicitWidth
                text: "SCAN"
                textSize: 12
                enabled: deviceMenu.isWifi ? (wifi.enabled && !wifi.scanning) : (bluetooth.enabled && !bluetooth.discovering)
                onClicked: {
                    if (deviceMenu.isWifi) wifi.refresh(true)
                    else bluetooth.rescan()
                }
            }
        }

        Rectangle {
            x: 0; y: 100
            width: parent.width
            height: 1
            color: Hud.cnBorderPassive
        }

        CnSegmented {
            x: 0; y: 112
            width: parent.width
            height: 32
            items: deviceMenu.isWifi
                   ? [{ key: "available", label: "AVAILABLE", count: wifi.networks.length },
                      { key: "saved", label: "SAVED", count: wifi.saved.length }]
                   : [{ key: "available", label: "AVAILABLE", count: bluetooth.devices.length },
                      { key: "saved", label: "PAIRED", count: bluetooth.paired.length }]
            value: deviceMenu.listFilter
            onSelected: (key) => deviceMenu.listFilter = key
        }

        // Network / device list
        ListView {
            id: list
            x: 0; y: 156
            width: parent.width
            height: parent.height - 172
            visible: !deviceMenu.authOpen
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            model: deviceMenu.isWifi
                   ? (deviceMenu.listFilter === "available" ? wifi.networks : wifi.saved)
                   : (deviceMenu.listFilter === "available" ? bluetooth.devices : bluetooth.paired)

            delegate: Item {
                id: row
                required property var modelData

                readonly property bool isWifi: deviceMenu.isWifi
                readonly property bool connected: isWifi ? Boolean(modelData.inUse) : Boolean(modelData.connected)
                readonly property bool saved: isWifi ? Boolean(modelData.saved) : Boolean(modelData.paired)
                readonly property bool busyRow: isWifi
                    ? (wifi.connectingSsid !== "" && wifi.connectingSsid === modelData.ssid)
                    : bluetooth.isBusy(modelData)
                readonly property bool errRow: isWifi
                    ? (wifi.error !== "" && wifi.errorSsid === modelData.ssid)
                    : (bluetooth.error !== "" && bluetooth.errorDevice === modelData)
                readonly property color rowInk: connected ? Hud.cnGround : Hud.cnInk
                readonly property color rowMuted: connected ? Hud.cnGround : Hud.cnTextMuted
                readonly property int lead: errRow ? 8 : 0
                readonly property int level: isWifi ? (Number(modelData.signal) || 0) : 0
                readonly property var thresholds: [1, 30, 55, 80]
                readonly property bool canDisconnect: connected
                readonly property bool canKey: isWifi && saved && !connected && Boolean(modelData.secured)
                readonly property bool canForget: saved && !connected
                readonly property bool hasActions: canDisconnect || canKey || canForget
                readonly property bool showActions: hover.hovered && !busyRow && hasActions
                readonly property int sideReserve: showActions ? actionRow.width + 12 : 96
                readonly property string statusCode: busyRow ? "LDG" : errRow ? "ERR" : connected ? "ACT" : saved ? "IDL" : ""
                readonly property string metaText: isWifi
                    ? (Boolean(modelData.secured) ? String(modelData.security).toUpperCase() : "OPEN")
                      + " · " + (level > 0 ? String(level).padStart(3, "0") + "%" : "OUT OF RANGE")
                    : bluetooth.kind(modelData)
                      + (bluetooth.batteryText(modelData) ? " · " + bluetooth.batteryText(modelData) : "")
                      + " · " + (saved ? "PAIRED" : "NEW")

                width: list.width
                height: 52

                HoverHandler { id: hover }

                CnCut {
                    anchors.fill: parent
                    br: 8
                    fill: row.connected ? Hud.cnInk : Hud.cnGround
                    edge: row.connected || hover.hovered || row.errRow ? Hud.cnInk : Hud.cnBorderPassive
                    edgeWidth: row.errRow ? 2 : 1
                }

                CnHatch {
                    visible: row.errRow
                    x: 2; y: 2
                    width: 8
                    height: row.height - 4
                    ink: row.rowInk
                }

                Text {
                    x: 12 + row.lead
                    y: 9
                    width: row.width - x - 12 - row.sideReserve
                    text: row.isWifi ? modelData.ssid : modelData.name
                    color: row.rowInk
                    font.family: Hud.font
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    x: 12 + row.lead
                    y: 31
                    width: row.width - x - 12 - row.sideReserve
                    text: row.metaText
                    color: row.rowMuted
                    font.family: Hud.mono
                    font.pixelSize: 10
                    font.letterSpacing: 1.2
                    elide: Text.ElideRight
                }

                // Signal meter (Wi-Fi only), left of the status mark.
                Item {
                    id: meter
                    visible: row.isWifi && !row.showActions
                    width: 18
                    height: 13
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: stateMark.visible ? stateMark.left : parent.right
                    anchors.rightMargin: stateMark.visible ? 8 : 12

                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            x: index * 5
                            anchors.bottom: parent.bottom
                            width: 3
                            height: 4 + index * 3
                            color: row.level >= row.thresholds[index]
                                   ? row.rowInk
                                   : (row.connected ? Hud.cnGround : Hud.cnBorderActive)
                        }
                    }
                }

                CnStatus {
                    id: stateMark
                    visible: !row.showActions && row.statusCode !== ""
                    width: implicitWidth
                    code: row.statusCode
                    // CnStatus draws an ERR chip as ink fill with ground text: on a white (connected) row, use white ink.
                    ink: row.statusCode === "ERR" ? Hud.cnInk : row.rowInk
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Row click: connect (non-connected, non-busy rows). Disconnect is the explicit button.
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (row.connected || row.busyRow) return
                        if (row.isWifi) wifi.connect(row.modelData)
                        else bluetooth.toggle(row.modelData)
                    }
                }

                // Hover actions, above the row's click area.
                Row {
                    id: actionRow
                    visible: row.showActions
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    CnButton {
                        visible: row.canDisconnect
                        height: 24
                        width: implicitWidth
                        text: "DISCONNECT"
                        textSize: 11
                        onClicked: {
                            if (row.isWifi) wifi.disconnect(row.modelData)
                            else bluetooth.toggle(row.modelData)
                        }
                    }
                    CnButton {
                        visible: row.canKey
                        height: 24
                        width: implicitWidth
                        text: "KEY"
                        textSize: 11
                        onClicked: deviceMenu.askPassword(row.modelData)
                    }
                    CnButton {
                        visible: row.canForget
                        height: 24
                        width: implicitWidth
                        text: "FORGET"
                        variant: "critical"
                        textSize: 11
                        onClicked: {
                            if (row.isWifi) wifi.forget(row.modelData)
                            else bluetooth.forget(row.modelData)
                        }
                    }
                }
            }
        }

        // Empty state, centred in the list area
        Item {
            x: 0; y: 156
            width: parent.width
            height: parent.height - 172
            visible: list.count === 0 && !deviceMenu.authOpen

            Column {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: deviceMenu.emptyInfo().code
                    color: Hud.cnTextMuted
                    font.family: Hud.mono
                    font.pixelSize: 11
                    font.letterSpacing: 0.66
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: text !== ""
                    text: deviceMenu.emptyInfo().hint
                    color: Hud.cnTextSecondary
                    font.family: Hud.font
                    font.pixelSize: 14
                }
            }
        }

        // Passphrase entry (Wi-Fi, after KEY or a failed connect)
        Item {
            id: authView
            x: 0; y: 156
            width: parent.width
            height: parent.height - 156
            visible: deviceMenu.authOpen
            transform: Translate { id: authShift }
            onVisibleChanged: if (visible) authIn.restart()

            ParallelAnimation {
                id: authIn
                CnAnim { target: authView; property: "opacity"; from: 0; to: 1; duration: 240 }
                CnAnim { target: authShift; property: "x"; from: 16; to: 0; duration: 240 }
            }

            Text {
                x: 0; y: 0
                text: "AUTH · " + (deviceMenu.authNet ? String(deviceMenu.authNet.security || "WPA").toUpperCase() : "")
                color: Hud.cnTextMuted
                font.family: Hud.mono
                font.pixelSize: 10
                font.letterSpacing: 1.2
            }

            Text {
                x: 0; y: 16
                width: parent.width
                text: deviceMenu.authNet ? String(deviceMenu.authNet.ssid) : ""
                color: Hud.cnInk
                font.family: Hud.font
                font.pixelSize: 18
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            CnButton {
                anchors.right: parent.right
                y: 42
                height: 24
                width: implicitWidth
                text: deviceMenu.showPassword ? "HIDE" : "SHOW"
                textSize: 11
                onClicked: deviceMenu.showPassword = !deviceMenu.showPassword
            }

            CnInput {
                id: passField
                x: 0; y: 48
                width: parent.width
                height: implicitHeight
                label: "PASSPHRASE"
                echoMode: deviceMenu.showPassword ? TextInput.Normal : TextInput.Password
                error: (wifi.error === "AUTH FAILED" && deviceMenu.authNet !== null && wifi.errorSsid === deviceMenu.authNet.ssid)
                       ? "Authentication failed.\nCheck the passphrase." : ""
                onAccepted: if (text.length >= 8) deviceMenu.submitAuth()
                onEscaped: deviceMenu.cancelAuth()
            }

            CnButton {
                x: 0
                y: passField.y + passField.implicitHeight + 16
                width: (parent.width - 8) / 2
                height: 32
                // Primary inverts even when disabled, so the disabled state drops to the outline style.
                variant: "primary"
                text: "CONNECT"
                enabled: passField.text.length >= 8
                onClicked: deviceMenu.submitAuth()
            }

            CnButton {
                x: (parent.width - 8) / 2 + 8
                y: passField.y + passField.implicitHeight + 16
                width: (parent.width - 8) / 2
                height: 32
                text: "CANCEL"
                onClicked: deviceMenu.cancelAuth()
            }
        }
    }
}
