# cpu-profile.nix — the bar's CPU profile switch (saver / balanced / performance).
# Each host brings its own helper script (hosts/<name>/cpu-profile, CPU specific);
# this installs it at the fixed path the bar calls and lets andrew run exactly that
# helper as root through pkexec without a password.
{ config, lib, pkgs, ... }:

let
  cfg = config.my.cpuProfile;
  # pkexec resets PATH to /usr/bin:/bin:… (nearly empty on NixOS), so the helper brings its own.
  helper = pkgs.writeScriptBin "cpu-profile" (
    lib.replaceStrings [ "#!/bin/sh\n" ] [ "#!${pkgs.runtimeShell}\nexport PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.gnugrep pkgs.gnused ]}\n" ]
      (builtins.readFile cfg.script)
  );
in
{
  options.my.cpuProfile.script = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = null;
    description = "Helper implementing `cpu-profile [saver|balanced|performance]` for this CPU.";
  };
  options.my.cpuProfile.package = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    default = helper;
    description = "The installed helper (exposed for tests).";
  };

  config = lib.mkIf (cfg.script != null) {
    environment.systemPackages = [ helper ];

    # Fixed path used by the bar and the polkit rule.
    systemd.tmpfiles.rules = [ "L+ /usr/local/bin/cpu-profile - - - - ${helper}/bin/cpu-profile" ];

    # pkexec hands polkit the resolved path (realpath), i.e. the store path, not the
    # /usr/local/bin link the bar calls. No subject.local / subject.active check on purpose: the bar runs as a systemd user
    # service, which logind puts in the seat-less "manager" session, so polkit sees it as
    # non-local and the check would always fail. The helper accepts only its 3 profiles.
    security.polkit.extraConfig = ''
      polkit.addRule(function (action, subject) {
          if (action.id == "org.freedesktop.policykit.exec" &&
              action.lookup("program") == "${helper}/bin/cpu-profile" &&
              subject.user == "andrew") {
              return polkit.Result.YES;
          }
      });
    '';
  };
}
