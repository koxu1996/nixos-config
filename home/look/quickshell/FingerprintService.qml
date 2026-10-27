// FingerprintService.qml: whether fprintd is waiting for a finger, for FingerprintChip.qml.
// Every fingerprint check (sudo, polkit, linux-passkey, hyprlock) goes through fprintd, whose
// device sets `finger-needed` while it waits; `gdbus monitor` follows those changes (and
// fprintd coming and going, since it is D-Bus activated and exits when idle).
// Hosts without fprintd (nixPC) simply never see it waiting.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: service

    // idle / waiting / matched (a moment after a successful check)
    property string status: "idle"
    readonly property bool waiting: status === "waiting"

    Process {
        id: monitor
        running: true
        command: ["gdbus", "monitor", "--system", "--dest", "net.reactivated.Fprint"]
        stdout: SplitParser { onRead: line => service.parse(line) }
        // gdbus should run for good; if it ever exits, start it again.
        onExited: { service.status = "idle"; restart.start(); }
    }
    Timer { id: restart; interval: 3000; onTriggered: monitor.running = true }

    // ".../Device/0: ...PropertiesChanged ('net.reactivated.Fprint.Device', {'finger-needed': <true>}, ...)"
    // ".../Device/0: ...VerifyStatus ('verify-match', true)"
    // "The name net.reactivated.Fprint does not have an owner" (fprintd exited)
    function parse(line) {
        if (line.includes("'finger-needed': <true>")) {
            matchedFade.stop();
            stopWaiting.stop();
            status = "waiting";
        } else if (line.includes("VerifyStatus ('verify-match'")) {
            stopWaiting.stop();
            status = "matched";
            matchedFade.restart();
        } else if ((line.includes("'finger-needed': <false>") || line.includes("does not have an owner"))
                   && status === "waiting") {
            // A match reports itself just after this; wait a moment so the chip goes
            // straight to the check mark instead of blinking off first.
            stopWaiting.restart();
        }
    }

    Timer { id: stopWaiting; interval: 150; onTriggered: if (service.status === "waiting") service.status = "idle" }
    Timer { id: matchedFade; interval: 1200; onTriggered: service.status = "idle" }
}
