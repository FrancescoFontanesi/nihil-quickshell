import QtQuick
import Quickshell
import Quickshell.Io

// Non-visual Wi-Fi model for the HUD: radio state, scan results, saved profiles, actions.
// Queries coalesce: a request while a process runs is queued, never a second process.
// Mutations all go through _runAction (one at a time, result handled in _finishAction).
Scope {
    id: wifi

    property bool active: false              // true while the Wi-Fi menu is visible
    property bool enabled: false             // radio state
    property bool busy: false                // an action process is running
    readonly property bool scanning: listProc.running
    property string device: ""               // wifi interface name
    property string activeSsid: ""
    property var networks: []                // available: [{ ssid, inUse, security, secured, saved, signal }]
    property var saved: []                   // saved profiles, offline ones have signal 0
    property var savedUuids: ({})            // ssid -> profile uuid
    property string connectingSsid: ""
    property string error: ""                // short uppercase reason
    property string errorSsid: ""

    signal passwordRequired(var net)
    signal radioChanged()

    property var _scanned: []
    property bool _listQueued: false
    property bool _listRescan: false
    property bool _radioQueued: false
    property bool _savedQueued: false
    property var _action: null
    property int _actionCode: 0
    property string _actionErr: ""
    property bool _actionExited: false
    property bool _actionStreamDone: false

    onActiveChanged: if (active) refresh(true)
    Component.onCompleted: {
        _startDevice()
        if (active) refresh(true)
    }

    function refresh(rescan) {
        if (device === "") _startDevice()
        _startRadio()
        _startSaved()
        if (enabled) _startList(!!rescan)
    }

    function clearError() {
        error = ""
        errorSsid = ""
    }

    function setEnabled(on) {
        if (!_runAction(["nmcli", "radio", "wifi", on ? "on" : "off"], { ssid: "", kind: "radio", net: null }))
            return false
        enabled = on
        if (!on) _scanned = []
        _rebuild()
        return true
    }

    function connect(net) {
        if (!net || net.inUse || busy) return false
        var uuid = uuidFor(net.ssid)
        var cmd
        if (net.saved && uuid !== "")
            cmd = ["nmcli", "--wait", "20", "connection", "up", "uuid", uuid]
        else if (!net.secured)
            cmd = ["nmcli", "--wait", "20", "device", "wifi", "connect", net.ssid]
        else {
            passwordRequired(net)
            return false
        }
        if (!_runAction(cmd, { ssid: net.ssid, kind: "connect", net: net, wasSaved: !!net.saved })) return false
        connectingSsid = net.ssid
        return true
    }

    function connectWithPassword(net, password) {
        if (!net || busy) return false
        var uuid = uuidFor(net.ssid)
        var cmd
        // shortcut: the password is visible in argv while nmcli runs; switch to a passwd-file if this machine becomes multi-user
        if (net.saved && uuid !== "")
            cmd = ["bash", "-c", "nmcli connection modify uuid \"$1\" wifi-sec.psk \"$2\" && nmcli --wait 20 connection up uuid \"$1\"", "_", uuid, password]
        else
            cmd = ["nmcli", "--wait", "20", "device", "wifi", "connect", net.ssid, "password", password]
        if (!_runAction(cmd, { ssid: net.ssid, kind: "password", net: net, wasSaved: !!net.saved })) return false
        connectingSsid = net.ssid
        return true
    }

    function disconnect(net) {
        if (!net || busy) return false
        var uuid = uuidFor(net.ssid)
        var cmd = uuid !== "" ? ["nmcli", "connection", "down", "uuid", uuid]
                              : ["nmcli", "connection", "down", "id", net.ssid]
        return _runAction(cmd, { ssid: net.ssid, kind: "disconnect", net: null })
    }

    function forget(net) {
        if (!net || busy) return false
        var uuid = uuidFor(net.ssid)
        var cmd = uuid !== "" ? ["nmcli", "connection", "delete", "uuid", uuid]
                              : ["nmcli", "connection", "delete", "id", net.ssid]
        if (!_runAction(cmd, { ssid: net.ssid, kind: "forget", net: null })) return false
        var next = ({})
        for (var k in savedUuids) if (k !== net.ssid) next[k] = savedUuids[k]
        savedUuids = next
        _rebuild()
        return true
    }

    // Exposed for the harness: maps an action's exit code and stderr to the short error code.
    function mapActionError(text, code) {
        if (code === 0) return ""
        var t = text || ""
        if (/secrets were required|802-1x|supplicant|psk|password/i.test(t)) return "AUTH FAILED"
        if (/no network with ssid/i.test(t)) return "NOT IN RANGE"
        if (/timeout|timed out/i.test(t)) return "TIMEOUT"
        if (/not authorized/i.test(t)) return "NOT AUTHORIZED"
        return "FAILED"
    }

    function uuidFor(ssid) {
        return Object.prototype.hasOwnProperty.call(savedUuids, ssid) ? savedUuids[ssid] : ""
    }

    // ---- queries ----
    function _startRadio() {
        if (radioProc.running) _radioQueued = true
        else radioProc.running = true
    }

    function _startSaved() {
        if (savedProc.running) _savedQueued = true
        else savedProc.running = true
    }

    function _startDevice() {
        if (!deviceProc.running) deviceProc.running = true
    }

    function _startList(rescan) {
        if (rescan) _listRescan = true
        if (listProc.running) {
            _listQueued = true
            return
        }
        _launchList()
    }

    function _launchList() {
        listProc.command = ["nmcli", "-e", "no", "-t", "-f", "IN-USE,SSID,SECURITY,SIGNAL", "device", "wifi", "list", "--rescan", _listRescan ? "yes" : "no"]
        _listRescan = false
        listProc.running = true
    }

    function _onRadio(on) {
        var was = enabled
        enabled = on
        if (!on) _scanned = []
        _rebuild()
        if (on && !was) _startList(true)
    }

    function _onSaved(text) {
        // One "uuid<TAB>ssid" line per Wi-Fi profile; key by SSID, not profile name.
        var lines = text.trim().split("\n")
        var uuids = ({})
        for (var i = 0; i < lines.length; ++i) {
            var parts = lines[i].split("\t")
            if (parts.length < 2) continue
            var ssid = parts[1].trim()
            if (!ssid || ssid === "-") continue
            uuids[ssid] = parts[0].trim()
        }
        savedUuids = uuids
        _rebuild()
    }

    function _onDevice(text) {
        var lines = text.trim().split("\n")
        for (var i = 0; i < lines.length; ++i) {
            var parts = lines[i].split(":")
            if (parts.length >= 2 && parts[parts.length - 1] === "wifi") {
                device = parts.slice(0, parts.length - 1).join(":")
                return
            }
        }
    }

    function _onList(text) {
        if (!enabled) return
        _scanned = parseWifiEntries(text)
        _rebuild()
    }

    function parseWifiEntries(output) {
        var entries = []
        var seen = Object.create(null)
        var lines = output.trim().split("\n")
        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i].trim()
            if (!line) continue
            var inUse = line.charAt(0) === "*"
            var rest = line.substring(line.indexOf(":") + 1)
            var parts = rest.split(":")
            if (parts.length < 3) continue
            // SSIDs may contain ':' (-e no): security and signal are the last two fields.
            var signal = parts[parts.length - 1]
            var security = parts[parts.length - 2]
            var ssid = parts.slice(0, parts.length - 2).join(":")
            if (!ssid) continue
            var secured = security !== "" && security !== "--"
            var level = parseInt(signal) || 0
            if (seen[ssid]) {
                var existing = seen[ssid]
                if (inUse || (!existing.inUse && level > existing.signal)) {
                    existing.signal = level
                    existing.security = security
                    existing.secured = secured
                }
                existing.inUse = existing.inUse || inUse
                continue
            }
            var entry = { ssid: ssid, inUse: inUse, security: security, secured: secured, saved: false, signal: level }
            seen[ssid] = entry
            entries.push(entry)
        }
        return entries
    }

    function _rankSort(a, b) {
        if (a.inUse !== b.inUse) return a.inUse ? -1 : 1
        if (a.saved !== b.saved) return a.saved ? -1 : 1
        return b.signal - a.signal
    }

    // Derives networks, saved, activeSsid from the last scan plus the saved-profile map.
    function _rebuild() {
        var byName = Object.create(null)
        var nets = []
        for (var i = 0; i < _scanned.length; ++i) {
            var s = _scanned[i]
            var net = { ssid: s.ssid, inUse: s.inUse, security: s.security, secured: s.secured,
                        saved: uuidFor(s.ssid) !== "", signal: s.signal }
            byName[s.ssid] = net
            nets.push(net)
        }
        var savedList = []
        var names = Object.keys(savedUuids)
        for (var j = 0; j < names.length; ++j) {
            var name = names[j]
            savedList.push(byName[name] || { ssid: name, inUse: false, security: "WPA2", secured: true, saved: true, signal: 0 })
        }
        nets.sort(_rankSort)
        savedList.sort(_rankSort)
        networks = nets
        saved = savedList

        var active = ""
        for (var k = 0; k < nets.length; ++k) if (nets[k].inUse) active = nets[k].ssid
        activeSsid = active
        if (connectingSsid !== "" && connectingSsid === active) connectingSsid = ""
    }

    // ---- actions ----
    function _runAction(cmd, ctx) {
        if (busy || actionProc.running) return false
        clearError()
        busy = true
        _action = ctx
        _actionErr = ""
        _actionCode = 0
        _actionExited = false
        _actionStreamDone = false
        actionProc.command = cmd
        actionProc.running = true
        return true
    }

    // The exit code and stderr arrive as two events; finish once both have.
    function _maybeFinishAction() {
        if (!_action || !_actionExited || !_actionStreamDone) return
        var a = _action
        _action = null
        _finishAction(_actionCode, _actionErr, a)
    }

    function _finishAction(code, text, a) {
        busy = false
        if (code !== 0) {
            error = mapActionError(text, code)
            errorSsid = a.ssid
            connectingSsid = ""
            if (a.kind === "password" && !a.wasSaved && !cleanupProc.running) {
                // nmcli keeps the profile it created with the wrong password; remove it.
                cleanupProc.command = ["nmcli", "connection", "delete", "id", a.ssid]
                cleanupProc.running = true
            }
            if (error === "AUTH FAILED" && a.net) passwordRequired(a.net)
        }
        refresh(false)
        radioChanged()
    }

    Process {
        id: radioProc
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: wifi._onRadio(text.trim() === "enabled")
        }
        onRunningChanged: {
            if (!running && wifi._radioQueued) {
                wifi._radioQueued = false
                wifi._startRadio()
            }
        }
    }

    Process {
        id: savedProc
        command: ["bash", "-c", "nmcli -t -f UUID,TYPE connection show | while IFS=: read -r u t; do [ \"$t\" = 802-11-wireless ] && printf '%s\\t%s\\n' \"$u\" \"$(nmcli -g 802-11-wireless.ssid connection show \"$u\")\"; done"]
        stdout: StdioCollector {
            onStreamFinished: wifi._onSaved(text)
        }
        onRunningChanged: {
            if (!running && wifi._savedQueued) {
                wifi._savedQueued = false
                wifi._startSaved()
            }
        }
    }

    Process {
        id: deviceProc
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE", "device"]
        stdout: StdioCollector {
            onStreamFinished: wifi._onDevice(text)
        }
    }

    Process {
        id: listProc
        command: ["nmcli", "-e", "no", "-t", "-f", "IN-USE,SSID,SECURITY,SIGNAL", "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: wifi._onList(text)
        }
        onRunningChanged: {
            if (!running && wifi._listQueued) {
                wifi._listQueued = false
                wifi._launchList()
            }
        }
    }

    Process {
        id: actionProc
        stderr: StdioCollector {
            onStreamFinished: {
                wifi._actionErr = text
                wifi._actionStreamDone = true
                wifi._maybeFinishAction()
            }
        }
        onExited: (exitCode) => {
            wifi._actionCode = exitCode
            wifi._actionExited = true
            wifi._maybeFinishAction()
        }
    }

    Process {
        id: cleanupProc
        onExited: wifi.refresh(false)
    }

    // nmcli monitor: any change event schedules one debounced refresh.
    Process {
        id: monitorProc
        command: ["nmcli", "monitor"]
        running: wifi.active
        stdout: SplitParser {
            onRead: debounce.restart()
        }
    }

    Timer {
        id: debounce
        interval: 600
        onTriggered: wifi.refresh(false)
    }

    Timer {
        interval: 20000
        repeat: true
        running: wifi.active && wifi.enabled
        onTriggered: wifi.refresh(true)
    }
}
