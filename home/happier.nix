# Happier (home/happier/package.nix): coding-agent sessions from the phone. Its daemon keeps
# this computer reachable through the relay so the app can start, follow and approve sessions
# here. One-time: `happier setup` (pick the relay, sign in), then
# `systemctl --user restart happier-daemon.default`.
#
# The unit mirrors the one `happier service install` writes (same name and markers, so
# `happier service status` recognises it), but runs the binary from the profile instead of a
# store path that goes stale on the next update. Don't run `happier service install`.
{ pkgs, ... }:

let
  happier = pkgs.callPackage ./happier/package.nix { };
in
{
  home.packages = [ happier ];

  systemd.user.services."happier-daemon.default" = {
    Unit = {
      Description = "Happier daemon";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${happier}/bin/happier daemon start-sync";
      Environment = [
        # The agents it starts (claude, opencode, …) and the tools they call.
        "PATH=/etc/profiles/per-user/%u/bin:/run/wrappers/bin:/run/current-system/sw/bin"
        "HAPPIER_DAEMON_STARTUP_SOURCE=background-service"
        "HAPPIER_DAEMON_SERVICE_TARGET_MODE=default-following"
      ];
      # Stopping the daemon leaves running agent sessions alone.
      KillMode = "process";
      ManagedOOMPreference = "avoid";
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
