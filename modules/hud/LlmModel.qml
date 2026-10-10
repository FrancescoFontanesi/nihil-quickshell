import QtQuick
import Quickshell
import Quickshell.Io

// State and commands of the external llm-wrapper daemon (see its README).
// Reads the daemon's state file, keeps the default provider in the shell state
// dir, and drives the daemon only through its CLI.
Scope {
    id: llm

    property string command: ""              // path to the llm-wrapper launcher
    readonly property bool available: command !== ""

    // Daemon state, from $XDG_RUNTIME_DIR/llm-wrapper.json
    property bool running: false
    property bool visible: false
    property string active: ""
    property var providers: ({})              // name -> url
    readonly property var names: Object.keys(providers)

    // Shell-side preference: the provider selected whenever the daemon starts.
    readonly property string defaultProvider: prefs.defaultProvider !== "" && providers[prefs.defaultProvider] !== undefined
                                              ? prefs.defaultProvider : (names.length ? names[0] : "")
    property bool _defaultApplied: false

    function code(name) {
        var known = { chatgpt: "GPT", gemini: "GEM", claude: "CLD", mistral: "MIS", perplexity: "PPX" }
        return known[name] || String(name).replace(/[^A-Za-z0-9]/g, "").slice(0, 3).toUpperCase()
    }

    // Input checks mirror the daemon's own (it ignores invalid input silently).
    function nameError(name) {
        if (!/^[A-Za-z0-9_-]{1,32}$/.test(name)) return "Use letters, digits, - or _ (max 32)."
        if (providers[name] !== undefined) return "A provider with this name exists."
        return ""
    }
    function urlError(url) {
        return /^https?:\/\/[^\s/$.?#][^\s]*$/i.test(url) ? "" : "Must start with http:// or https://."
    }

    // Every command carries --show/--hide: without one the daemon shows its window.
    function run(args) {
        if (!available) return
        Quickshell.execDetached([command].concat(args).concat([visible ? "--show" : "--hide"]))
    }

    function select(name) {
        if (name === active) return
        active = name                          // optimistic; the state file confirms
        run(["--provider", name])
    }
    function add(name, url) {
        if (nameError(name) !== "" || urlError(url) !== "") return false
        run(["--add-provider", name, url])
        return true
    }
    function remove(name) {
        if (providers[name] === undefined || names.length < 2) return
        if (name === active) select(defaultProvider !== name ? defaultProvider : names.find(n => n !== name))
        if (name === prefs.defaultProvider) prefs.defaultProvider = ""
        run(["--remove-provider", name])
    }
    function setDefault(name) {
        if (providers[name] !== undefined) prefs.defaultProvider = name
    }

    function _onState(text) {
        var s
        try { s = JSON.parse(text) } catch (e) { return }
        running = true
        visible = !!s.visible
        active = s.active || ""
        providers = s.providers || {}
        if (!_defaultApplied && defaultProvider !== "") {
            _defaultApplied = true
            if (active !== defaultProvider) select(defaultProvider)
        }
    }

    FileView {
        id: stateFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/llm-wrapper.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: llm._onState(text())
        onLoadFailed: {
            // No state file: the daemon is not running; re-apply the default when it returns.
            llm.running = false
            llm.visible = false
            llm._defaultApplied = false
        }
    }

    FileView {
        path: Quickshell.statePath("llm.json")
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoadFailed: (error) => { if (error === FileViewError.FileNotFound) writeAdapter() }

        JsonAdapter {
            id: prefs
            property string defaultProvider: ""
        }
    }

    // shortcut: the state file is replaced atomically; if the watch drops it, this
    // poll (only while the daemon is gone or the HUD asks) picks the daemon up again.
    function refresh() { stateFile.reload() }
    Timer {
        interval: 5000
        repeat: true
        running: !llm.running && llm.available
        onTriggered: stateFile.reload()
    }
}
