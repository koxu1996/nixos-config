# nixAir-only Home Manager settings: bar features, built-in Retina panel, screenshot key.
# Touchpad, function row and media keys are shared (home/hyprland.nix).
{ lib, ... }:

{
  # Bar features of this MacBook (home/look).
  my.look = {
    wifi = true;
    battery = true;
    glowBrightness = true;
    notchGap = 200; # notch + margin (kernel appledrm.show_notch=1)
    cpuProfile = "battery";
    # Asahi exposes no SoC die temperature; the WiFi/BT module reacts fastest to CPU load.
    # SoC load shows best as the SMC's heatpipe power (~1 W idle, ~18 W all cores busy).
    machine = {
      name = "MacBook Air · M2";
      cores = "4 E-cores + 4 P-cores";
      notes = "fanless";
      coreCount = 8;
      eCores = [ 0 1 2 3 ];
      tempLabel = "WiFi/BT Module Temp";
      powerLabel = "Heatpipe Power";
    };
  };

  # Wallpaper from the repo.
  my.wallpaper = "${../../wallpapers/violet-sunset-kraken.jpg}";

  wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
    -- Built-in Retina panel (2560x1664, with the notch 2560x1728) needs 2x scaling;
    -- any other monitor gets its preferred mode at scale 1.
    hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 2 })
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

    -- No Print key: region screenshot (bar tools) with mainMod + SHIFT + s.
    hl.bind(key(mainMod .. " + SHIFT", "s"), hl.dsp.exec_cmd(tools .. "screenshot region"))
  '';
}
