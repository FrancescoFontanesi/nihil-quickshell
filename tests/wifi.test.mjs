// Node test for modules/hud/wifi.js (the pure nmcli parsers used by WifiModel.qml).
// Run: node tests/wifi.test.mjs
import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";

const src = fs.readFileSync(new URL("../modules/hud/wifi.js", import.meta.url), "utf8")
    .replace(/^\.pragma library\s*$/m, "");
const { parseWifiEntries, mapActionError } = vm.runInNewContext(
    src + "\n;({parseWifiEntries, mapActionError})", {});

// Results come from another realm; compare plain JSON copies.
const plain = (v) => JSON.parse(JSON.stringify(v));
const parse = (...rows) => plain(parseWifiEntries(rows.join("\n")));

let passed = 0;
function check(fn) {
    fn();
    passed++;
}

// Rows in the exact shape of `nmcli -e no -t -f IN-USE,SSID,SECURITY,SIGNAL device wifi list`.
check(() => {
    const [e] = parse(":Cafe:Net:--:40");
    assert.equal(e.ssid, "Cafe:Net");
    assert.equal(e.signal, 40);
});

check(() => {
    const [e] = parse("*:HomeNet:WPA2 WPA3:78");
    assert.equal(e.ssid, "HomeNet");
    assert.equal(e.inUse, true);
    assert.equal(e.secured, true);
    assert.equal(e.signal, 78);
});

check(() => {
    const [a] = parse(":Open1:--:50");
    assert.equal(a.secured, false);
    const [b] = parse(":Open2::30");
    assert.equal(b.secured, false);
});

check(() => {
    // Duplicate SSIDs: a weaker row first, a stronger row after; the stronger one wins.
    const merged = parse(":Dup:WPA2:30", ":Dup:--:70");
    assert.equal(merged.length, 1);
    assert.equal(merged[0].signal, 70);
    assert.equal(merged[0].secured, false);
    assert.equal(merged[0].inUse, false);
});

check(() => {
    // An in-use row replaces the signal even when weaker, and inUse is sticky.
    const merged = parse("*:Dup:WPA2:40", ":Dup:--:78");
    assert.equal(merged.length, 1);
    assert.equal(merged[0].inUse, true);
    assert.equal(merged[0].signal, 40);
    assert.equal(merged[0].secured, true);
});

check(() => {
    const merged = parse(":Dup:WPA2:30", "*:Dup:WPA2:20");
    assert.equal(merged.length, 1);
    assert.equal(merged[0].inUse, true);
    assert.equal(merged[0].signal, 20);
});

check(() => {
    // Empty SSID rows are skipped; the row after them is kept.
    const entries = parse("*::WPA2:60", ":Kept:WPA2:45");
    assert.deepEqual(entries.map((e) => e.ssid), ["Kept"]);
});

check(() => {
    assert.deepEqual(plain(parseWifiEntries("")), []);
    assert.deepEqual(plain(parseWifiEntries("\n  \n")), []);
});

check(() => assert.equal(mapActionError("Secrets were required, but not provided", 0), ""));
check(() => assert.equal(mapActionError("Secrets were required, but not provided", 4), "AUTH FAILED"));
check(() => assert.equal(mapActionError("No network with SSID 'x' found", 10), "NOT IN RANGE"));
check(() => assert.equal(mapActionError("Timeout expired", 5), "TIMEOUT"));
check(() => assert.equal(mapActionError("Not authorized to control networking", 8), "NOT AUTHORIZED"));
check(() => assert.equal(mapActionError("something else entirely", 1), "FAILED"));
check(() => assert.equal(mapActionError("", 1), "FAILED"));

console.log(`wifi tests: ${passed} passed`);
