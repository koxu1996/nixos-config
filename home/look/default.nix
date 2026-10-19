# The desktop look shared by every host: Quickshell bar, lime palette, terminal and
# Hyprland behaviour (home/hyprland.nix). Hardware differences are the my.look.*
# options below; each host sets them, the bar reads them from a generated Host.qml.
{ lib, ... }:

{
  imports = [
    ./quickshell.nix
    ./terminal.nix
  ];

  options.my.look = {
    wifi = lib.mkOption {
      type = lib.types.bool;
      description = "Show the Wi-Fi chip (iwd backend).";
    };
    battery = lib.mkOption {
      type = lib.types.bool;
      description = "Show the battery chip and panel.";
    };
    glowBrightness = lib.mkOption {
      type = lib.types.bool;
      description = "Glow also controls the panel backlight (laptops); otherwise colour temperature only.";
    };
    notchGap = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 0;
      description = "Width (px) kept free around the screen centre on a notched built-in panel.";
    };
    machine = {
      name = lib.mkOption { type = lib.types.str; description = "Title of the CPU/MEM panel."; };
      cores = lib.mkOption { type = lib.types.str; description = "Core summary under the title, e.g. \"8 cores\"."; };
      notes = lib.mkOption { type = lib.types.str; default = ""; description = "Extra words after the memory size, e.g. \"fanless\"."; };
      coreCount = lib.mkOption { type = lib.types.ints.positive; description = "Logical CPUs shown as per-core bars."; };
      eCores = lib.mkOption {
        type = lib.types.listOf lib.types.ints.unsigned;
        default = [ ];
        description = "Indexes of efficiency cores (grey bars, E1…); the rest are P-cores (or plain cores when empty).";
      };
      tempLabel = lib.mkOption { type = lib.types.str; description = "hwmon temp*_label for the temperature chart."; };
      tempWarm = lib.mkOption { type = lib.types.int; default = 80; description = "°C shown as warm."; };
      tempThrottle = lib.mkOption { type = lib.types.int; default = 95; description = "°C shown as throttling."; };
      powerLabel = lib.mkOption { type = lib.types.str; default = ""; description = "hwmon power*_label for the power chart; empty = no power chart."; };
    };
    cpuProfile = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "battery" "stats" ]);
      description = "Where the CPU profile switch is shown (battery panel or CPU/MEM panel); null = nowhere.";
    };
  };
}
