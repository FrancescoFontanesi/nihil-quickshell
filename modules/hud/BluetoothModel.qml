import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Non-visual Bluetooth state for the device drawer (Quickshell native BlueZ service).
Scope {
    id: bt

    property bool active: false // true while the Bluetooth menu is visible
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: !!adapter
    readonly property bool enabled: available && adapter.enabled
    readonly property bool busy: available && (adapter.state === BluetoothAdapterState.Enabling
                                               || adapter.state === BluetoothAdapterState.Disabling)
    readonly property bool discovering: available && adapter.discovering

    readonly property var devices: adapter ? adapter.devices.values.filter(function(d) {
        // BlueZ falls back to the address as the alias when a device has no name.
        return d.paired || d.connected || d.name.replace(/-/g, ":").toUpperCase() !== d.address.toUpperCase()
    }).sort(function(a, b) {
        if (a.connected !== b.connected) return a.connected ? -1 : 1
        if (a.paired !== b.paired) return a.paired ? -1 : 1
        return a.name.localeCompare(b.name)
    }) : []
    readonly property var paired: devices.filter(function(d) { return d.paired }).sort(function(a, b) {
        if (a.connected !== b.connected) return a.connected ? -1 : 1
        return a.name.localeCompare(b.name)
    })

    property var pending: null
    property string pendingKind: "" // "pair" | "connect" | "disconnect"
    property string error: "" // "PAIR FAILED" | "CONNECT FAILED" | "TIMEOUT" | ""
    property var errorDevice: null
    property bool connectingSeen: false

    // Discovery: on while the menu is open, off after 20s.
    Timer {
        id: scanTimer
        interval: 20000
        onTriggered: bt.stopScan()
    }

    Timer {
        id: pairCheck
        interval: 1500
        onTriggered: if (bt.pendingKind === "pair" && bt.pending && !bt.pending.paired) bt.fail("PAIR FAILED")
    }

    // Guards a pending action that never resolves.
    Timer {
        id: timeoutTimer
        interval: 25000
        onTriggered: if (bt.pending) bt.fail("TIMEOUT")
    }

    onActiveChanged: active && enabled ? rescan() : stopScan()
    onEnabledChanged: { if (enabled && active) rescan(); else if (!enabled) stopScan() }
    Component.onCompleted: if (active && enabled) rescan()

    function setEnabled(on) {
        if (!available) return
        adapter.enabled = on
        if (!on) stopScan()
    }

    function rescan() {
        if (!enabled) return
        adapter.discovering = true
        scanTimer.restart()
    }

    function stopScan() {
        scanTimer.stop()
        if (available) adapter.discovering = false
    }

    function setPending(device, kind) {
        pending = device
        pendingKind = kind
        connectingSeen = false
        timeoutTimer.restart()
    }

    function done() {
        pending = null
        pendingKind = ""
        timeoutTimer.stop()
    }

    function fail(reason) {
        error = reason
        errorDevice = pending
        pending = null
        pendingKind = ""
        timeoutTimer.stop()
    }

    function clearError() {
        error = ""
        errorDevice = null
    }

    function toggle(device) {
        if (!device) return
        clearError()
        if (device.connected) {
            setPending(device, "disconnect")
            device.disconnect()
        } else if (!device.paired) {
            device.trusted = true
            setPending(device, "pair")
            device.pair()
        } else {
            setPending(device, "connect")
            device.connect()
        }
    }

    function forget(device) {
        if (!device) return
        clearError()
        device.forget()
    }

    // Resolve pending actions from device signals.
    Connections {
        target: bt.pending
        ignoreUnknownSignals: true

        function onPairedChanged() {
            if (bt.pendingKind === "pair" && bt.pending.paired) {
                bt.pendingKind = "connect"
                bt.connectingSeen = false
                timeoutTimer.restart()
                bt.pending.connect()
            }
        }
        function onPairingChanged() {
            // The pair() call can return before BlueZ reports Paired: judge a moment later.
            if (bt.pendingKind === "pair" && !bt.pending.pairing && !bt.pending.paired)
                pairCheck.restart()
        }
        function onConnectedChanged() {
            if (bt.pendingKind === "connect" && bt.pending.connected) bt.done()
            else if (bt.pendingKind === "disconnect" && !bt.pending.connected) bt.done()
        }
        function onStateChanged() {
            if (bt.pendingKind !== "connect") return
            if (bt.pending.state === BluetoothDeviceState.Connecting) {
                bt.connectingSeen = true
            } else if (bt.connectingSeen && bt.pending.state === BluetoothDeviceState.Disconnected
                       && !bt.pending.connected) {
                bt.fail("CONNECT FAILED")
            }
        }
    }

    function kind(device) {
        var i = device && device.icon ? device.icon : ""
        if (i.startsWith("audio")) return "AUD"
        switch (i) {
        case "input-keyboard": return "KBD"
        case "input-mouse": return "PTR"
        case "input-gaming": return "PAD"
        case "input-tablet": return "TAB"
        case "phone": return "PHN"
        case "computer": return "CMP"
        }
        return "DEV"
    }

    function batteryText(device) {
        if (!device || !device.batteryAvailable) return ""
        var p = Math.max(0, Math.min(100, Math.round(device.battery * 100)))
        return "BAT " + String(p).padStart(3, "0") + "%"
    }

    function isBusy(device) {
        if (!device) return false
        return device.pairing
            || device.state === BluetoothDeviceState.Connecting
            || device.state === BluetoothDeviceState.Disconnecting
            || device === pending
    }
}
