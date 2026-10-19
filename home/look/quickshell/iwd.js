.pragma library
// iwd.js: parsing for WifiService.qml. Input is `busctl --json=short` output of iwd's D-Bus API
// (net.connman.iwd): ObjectManager.GetManagedObjects, Station.GetOrderedNetworks and
// StationDiagnostic.GetDiagnostics. Pure functions, tested by tests/iwd/iwd.test.js (node).

// busctl wraps every value as { type, data }.
function v(x) { return x && typeof x === "object" && "data" in x ? x.data : x; }

// -> { station: { path, state, scanning, connectedPath, connectedSsid }, model,
//      networks: { path: { ssid, type, connected, knownPath } }, known: [{ path, ssid, type }] }
function parseManagedObjects(reply) {
    const out = {
        station: { path: "", state: "", scanning: false, connectedPath: "", connectedSsid: "" },
        model: "",
        networks: {},
        known: [],
    };
    const objects = (reply && reply.data && reply.data[0]) || {};
    for (const path of Object.keys(objects)) {
        const ifaces = objects[path];
        const adapter = ifaces["net.connman.iwd.Adapter"];
        if (adapter) out.model = v(adapter.Model) || v(adapter.Vendor) || "";
        const station = ifaces["net.connman.iwd.Station"];
        if (station) {
            out.station.path = path;
            out.station.state = v(station.State) || "";
            out.station.scanning = !!v(station.Scanning);
            out.station.connectedPath = v(station.ConnectedNetwork) || "";
        }
        const net = ifaces["net.connman.iwd.Network"];
        if (net) out.networks[path] = {
            ssid: v(net.Name) || "",
            type: v(net.Type) || "",
            connected: !!v(net.Connected),
            knownPath: v(net.KnownNetwork) || "",
        };
        const known = ifaces["net.connman.iwd.KnownNetwork"];
        if (known) out.known.push({ path, ssid: v(known.Name) || "", type: v(known.Type) || "" });
    }
    const current = out.networks[out.station.connectedPath];
    out.station.connectedSsid = current ? current.ssid : "";
    return out;
}

// GetOrderedNetworks -> { networkPath: dBm } (iwd reports 100 * dBm).
function parseOrdered(reply) {
    const out = {};
    const list = (reply && reply.data && reply.data[0]) || [];
    for (const entry of list) out[entry[0]] = Math.round(entry[1] / 100);
    return out;
}

function levelOf(dbm) {
    return dbm >= -55 ? 4 : dbm >= -65 ? 3 : dbm >= -75 ? 2 : 1;
}

// iwd network type -> the labels Wifi.qml uses ("open" and "EAP" change what it offers).
function securityOfType(type) {
    return type === "open" ? "open" : type === "8021x" ? "EAP" : type === "wep" ? "WEP" : "WPA2";
}

// Networks in range for the list: saved first, then by signal; the connected one left out.
// Each: { ssid, security, saved, path, knownPath, rssi, level, bands } (iwd doesn't expose
// per-network bands, so bands is empty).
function networkList(objs, ordered) {
    const rows = [];
    for (const path of Object.keys(objs.networks || {})) {
        const n = objs.networks[path];
        if (n.connected || !n.ssid) continue;
        const rssi = ordered[path] !== undefined ? ordered[path] : -100;
        rows.push({
            ssid: n.ssid,
            security: securityOfType(n.type),
            saved: n.knownPath !== "",
            path: path,
            knownPath: n.knownPath,
            rssi: rssi,
            level: levelOf(rssi),
            bands: [],
        });
    }
    return rows.sort((a, b) => (b.saved - a.saved) || (b.rssi - a.rssi));
}

// GetDiagnostics -> link details for the current-network card.
function parseDiagnostics(reply) {
    const d = (reply && reply.data && reply.data[0]) || {};
    const mode = v(d.RxMode) || v(d.TxMode) || "";
    const gen = { "802.11be": 7, "802.11ax": 6, "802.11ac": 5, "802.11n": 4 }[mode] || 0;
    const sec = v(d.Security) || "";
    return {
        bssid: v(d.ConnectedBss) || "",
        freq: v(d.Frequency) || 0,
        rssi: v(d.RSSI) || 0,
        linkSpeed: Math.round((v(d.TxBitrate) || 0) / 10), // 100 kbit/s units -> Mbit/s
        wifiGeneration: gen,
        security: /WPA3/.test(sec) ? "WPA3" : /WPA2/.test(sec) ? "WPA2" : /WPA/.test(sec) ? "WPA"
                : sec === "Open" ? "Open" : sec,
    };
}
