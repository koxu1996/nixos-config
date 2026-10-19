// Node test for home/look/quickshell/iwd.js (the iwd D-Bus parsing used by WifiService.qml).
// Run: node tests/iwd/iwd.test.js
const fs = require("fs"), path = require("path"), assert = require("assert");
const src = fs.readFileSync(path.join(__dirname, "../../home/look/quickshell/iwd.js"), "utf8")
    .replace(/^\.pragma library.*$/m, ""); // QML-only directive
const Iwd = {};
new Function("exports", src + "\nfor (const k of Object.keys(this)) {}" +
    "\nexports.parseManagedObjects = parseManagedObjects; exports.parseOrdered = parseOrdered;" +
    "\nexports.networkList = networkList; exports.parseDiagnostics = parseDiagnostics; exports.levelOf = levelOf;")(Iwd);
const read = f => JSON.parse(fs.readFileSync(path.join(__dirname, f), "utf8"));

const objs = Iwd.parseManagedObjects(read("managed-objects.json"));
assert.strictEqual(objs.station.path, "/net/connman/iwd/0/4");
assert.strictEqual(objs.station.state, "connected");
assert.strictEqual(objs.station.scanning, false);
assert.strictEqual(objs.station.connectedSsid, "home");
assert.strictEqual(objs.model, "BCM4387");
assert.deepStrictEqual(objs.known.map(k => k.ssid).sort(), ["home", "old"]);

const ordered = Iwd.parseOrdered(read("ordered-networks.json"));
assert.strictEqual(ordered["/net/connman/iwd/0/4/686f6d65_psk"], -48);

const list = Iwd.networkList(objs, ordered);
// Saved first, then by signal; the connected network left out.
assert.deepStrictEqual(list.map(n => n.ssid), ["neighbour", "café", "work"]);
const byName = Object.fromEntries(list.map(n => [n.ssid, n]));
assert.strictEqual(byName["café"].security, "open");
assert.strictEqual(byName.work.security, "EAP");
assert.strictEqual(byName.neighbour.security, "WPA2");
assert.strictEqual(byName.neighbour.saved, false);
assert.strictEqual(byName.neighbour.rssi, -61);
assert.strictEqual(byName.neighbour.level, 3);
assert.deepStrictEqual(byName.neighbour.bands, []);

// A saved network that is in range but not connected sorts first.
const objs2 = JSON.parse(JSON.stringify(read("managed-objects.json")));
const d = objs2.data[0];
d["/net/connman/iwd/0/4"]["net.connman.iwd.Station"].State.data = "disconnected";
delete d["/net/connman/iwd/0/4"]["net.connman.iwd.Station"].ConnectedNetwork;
d["/net/connman/iwd/0/4/686f6d65_psk"]["net.connman.iwd.Network"].Connected.data = false;
const p2 = Iwd.parseManagedObjects(objs2);
assert.strictEqual(p2.station.connectedSsid, "");
const l2 = Iwd.networkList(p2, ordered);
assert.strictEqual(l2[0].ssid, "home");
assert.strictEqual(l2[0].saved, true);
assert.strictEqual(l2[0].knownPath, "/net/connman/iwd/686f6d65_psk");

// No station (radio off / device down): empty, no throw.
const p3 = Iwd.parseManagedObjects({ type: "a{oa{sa{sv}}}", data: [{}] });
assert.strictEqual(p3.station.path, "");
assert.deepStrictEqual(Iwd.networkList(p3, {}), []);
assert.deepStrictEqual(Iwd.parseManagedObjects(null).known, []);

const diag = Iwd.parseDiagnostics(read("diagnostics.json"));
assert.deepStrictEqual(diag, { bssid: "11:22:33:44:55:66", freq: 5180, rssi: -48, linkSpeed: 866, wifiGeneration: 6, security: "WPA3" });
assert.deepStrictEqual(Iwd.parseDiagnostics(null), { bssid: "", freq: 0, rssi: 0, linkSpeed: 0, wifiGeneration: 0, security: "" });

console.log("iwd.test.js: all assertions passed");
