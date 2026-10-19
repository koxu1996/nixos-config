// CpuProfileService.qml: the CPU profile (saver, balanced, performance) for whichever panel
// shows it (Host.cpuProfile: battery panel on the MacBook, CPU/MEM panel on the workstation).
// Reading: `/usr/local/bin/cpu-profile` without an argument prints "profile=..." and
// "detail=..." (no root needed). Switching: `pkexec /usr/local/bin/cpu-profile <name>`,
// allowed without a password by modules/cpu-profile.nix. The helper is CPU specific
// (hosts/<name>/cpu-profile); this file is not.
// Keep braces out of this header: Quickshell stops looking for `pragma Singleton` at the first one.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: service

    readonly property string helper: "/usr/local/bin/cpu-profile"

    property string profile: ""        // "saver" | "balanced" | "performance" | "custom" (as read)
    property string profileDetail: ""  // the helper's one-line description
    property string pendingProfile: "" // selection while the helper runs
    property string profileError: ""

    function readProfile() { if (Host.cpuProfile !== "" && !reader.running) reader.running = true; }

    Process {
        id: reader
        command: [service.helper]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.trim().split("\n")) {
                    const i = line.indexOf("=");
                    if (i < 0) continue;
                    const key = line.slice(0, i), value = line.slice(i + 1);
                    if (key === "profile") service.profile = value;
                    else if (key === "detail") service.profileDetail = value;
                }
            }
        }
    }

    function setProfile(name) {
        if (runner.running) return;
        profileError = "";
        pendingProfile = name;
        runner.command = ["pkexec", helper, name];
        runner.running = true;
    }

    Process {
        id: runner
        stderr: StdioCollector { id: runnerStderr }
        onExited: (code, status) => {
            if (code !== 0) {
                const why = code === 126 ? "authorization refused"
                          : code === 127 ? `${service.helper} missing or not authorized`
                          : (runnerStderr.text.trim().split("\n").pop() || `exit ${code}`);
                service.profileError = `Couldn't apply: ${why}`;
            }
            service.pendingProfile = "";
            service.readProfile(); // confirm (or revert) from sysfs
        }
    }

    Component.onCompleted: readProfile()
}
