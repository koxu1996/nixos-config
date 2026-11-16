# Claude dock (quickshell/ClaudeDock.qml, ClaudeAgents.qml): Herdr's coding agents on every
# machine, as dots on the right screen edge. This machine's agents come from its default
# Herdr session, whose server runs as herdr-server from login on (so the dock's "+" can
# start sessions here before any `herdr` window is open); each other machine's Herdr
# socket is forwarded over SSH to $XDG_RUNTIME_DIR/herdr-<LABEL>.sock by
# herdr-forward-<LABEL>, which retries every 30 s while that machine is off or unreachable. A machine without a running Herdr server just
# shows no agents.
{ config, lib, pkgs, osConfig, ... }:
let
  # Hostname -> the dock's label (the same list as ClaudeAgents.qml). The hostname is
  # also the SSH host (modules/ssh.nix, ~/.ssh/config).
  machines = { nixAir = "AIR"; nixPC = "PC"; nixvps = "VPS"; nuc = "NUC"; };
  others = lib.filterAttrs (host: _: host != osConfig.networking.hostName) machines;

  forward = host: label: lib.nameValuePair "herdr-forward-${label}" {
    Unit.Description = "Herdr socket of ${host}, for the Claude dock";
    Service = {
      ExecStart = lib.escapeShellArgs [
        "${pkgs.openssh}/bin/ssh" "-N"
        "-o" "BatchMode=yes"
        "-o" "ConnectTimeout=10"
        "-o" "ServerAliveInterval=30"
        "-o" "ServerAliveCountMax=3"
        "-o" "ExitOnForwardFailure=yes"
        "-o" "StreamLocalBindUnlink=yes"
        "-L" "%t/herdr-${label}.sock:/home/andrew/.config/herdr/herdr.sock"
        host
      ];
      Restart = "always";
      RestartSec = 30;
    };
    Install.WantedBy = [ "default.target" ];
  };
in
{
  systemd.user.services = lib.mapAttrs' forward others // {
    # The default session's server, headless; `herdr` windows attach to it. Never restarted
    # by a switch (keep-old): that would end every agent in it.
    herdr-server = {
      Unit = {
        Description = "Herdr server (default session)";
        X-SwitchMethod = "keep-old";
      };
      Service = {
        ExecStart = "${pkgs.herdr}/bin/herdr server";
        WorkingDirectory = "%h";
        # Its panes run your shell and agents: the session's PATH, as the bar has.
        Environment = [ "PATH=/run/wrappers/bin:/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin" ];
        Restart = "on-failure";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
