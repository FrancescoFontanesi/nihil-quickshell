.pragma library

function mapActionError(text, code) {
    if (code === 0) return ""
    var t = text || ""
    if (/secrets were required|802-1x|supplicant|psk|password/i.test(t)) return "AUTH FAILED"
    if (/no network with ssid/i.test(t)) return "NOT IN RANGE"
    if (/timeout|timed out/i.test(t)) return "TIMEOUT"
    if (/not authorized/i.test(t)) return "NOT AUTHORIZED"
    return "FAILED"
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
