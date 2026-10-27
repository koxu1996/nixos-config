// FingerprintService.qml: what a fingerprint check is doing, for FingerprintChip.qml.
// Every fingerprint check (sudo, polkit, linux-passkey, hyprlock) goes through fprintd. Its
// device sets `finger-needed` while it waits and `finger-present` while a finger is being read
// (the Apple SEP driver: the sensor's "hold still"), and VerifyStatus reports each attempt.
// `gdbus monitor` follows all of it, and fprintd coming and going (it is D-Bus activated and
// exits when idle). Hosts without fprintd (nixPC) simply never see a check.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: service

    // idle / waiting / reading, or for a moment after an attempt: matched / retry / nomatch / error
    readonly property string status: flash !== "" ? flash : present ? "reading" : active ? "waiting" : "idle"
    // What to say for retry / nomatch / error ("Try again", "Center your finger", …).
    property string flashText: ""

    property bool needed: false
    property bool present: false
    // needed || present, but let go 150 ms late: between two states (needed → present, or the
    // end of an attempt → its result) fprintd briefly reports neither, and the chip would blink.
    property bool active: false
    property string flash: ""
    // A finger touched the sensor during this attempt (reset by VerifyFingerSelected, sent at
    // every start). A cancelled check also ends with verify-no-match; without a touch that is
    // not worth a red "No match".
    property bool touched: false

    onNeededChanged: settle()
    onPresentChanged: { if (present) touched = true; settle(); }
    function settle() {
        if (needed || present) { letGo.stop(); active = true; }
        else letGo.restart();
    }
    Timer { id: letGo; interval: 150; onTriggered: service.active = false }

    function show(kind, text, ms) {
        flash = kind;
        flashText = text;
        flashTimer.interval = ms;
        flashTimer.restart();
    }
    Timer { id: flashTimer; onTriggered: service.flash = "" }

    Process {
        id: monitor
        running: true
        command: ["gdbus", "monitor", "--system", "--dest", "net.reactivated.Fprint"]
        stdout: SplitParser { onRead: line => service.parse(line) }
        // gdbus should run for good; if it ever exits, start it again.
        onExited: { service.needed = false; service.present = false; restart.start(); }
    }
    Timer { id: restart; interval: 3000; onTriggered: monitor.running = true }

    // Retry codes fprintd sends while the check goes on (done = false).
    readonly property var retryText: ({
        "verify-retry-scan": "Try again",
        "verify-swipe-too-short": "Too short, try again",
        "verify-finger-not-centered": "Center your finger",
        "verify-remove-and-retry": "Lift and try again",
    })

    // ".../Device/0: ...PropertiesChanged ('net.reactivated.Fprint.Device', {'finger-needed': <true>}, @as [])"
    //   (one change can carry both properties)
    // ".../Device/0: ...VerifyFingerSelected ('right-index-finger',)" (an attempt starts)
    // ".../Device/0: ...VerifyStatus ('verify-match', true)"
    // "The name net.reactivated.Fprint does not have an owner" (fprintd exited)
    function parse(line) {
        if (line.includes("VerifyFingerSelected")) touched = false;
        const needs = line.match(/'finger-needed': <(true|false)>/);
        if (needs) needed = needs[1] === "true";
        const has = line.match(/'finger-present': <(true|false)>/);
        if (has) present = has[1] === "true";

        const result = line.match(/VerifyStatus \('([a-z-]+)'/);
        if (result) {
            const code = result[1];
            if (code === "verify-match") show("matched", "", 1200);
            else if (code in retryText) { touched = true; show("retry", retryText[code], 1500); }
            else if (code === "verify-no-match") { if (touched) show("nomatch", "No match", 1500); }
            else show("error", "Sensor error", 2500); // verify-disconnected, verify-unknown-error
        }

        if (line.includes("does not have an owner")) { needed = false; present = false; touched = false; }
    }
}
