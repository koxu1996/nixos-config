# nixAir-only Home Manager settings: main key, built-in Retina panel, touchpad.
{ lib, ... }:

{
  # Cmd (Super) is the main key on the Mac; Option (Alt) is the secondary one,
  # so the lock screen is Option+L here.
  my.hyprland.mainMod = "SUPER";

  # Wallpaper from the repo (same image as on the Mac's Arch setup).
  my.wallpaper = "${../../wallpapers/space1.jpg}";

  wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
    -- Built-in Retina panel (2560x1664) needs 2x scaling.
    hl.monitor({
      output = "",
      mode = "preferred",
      position = "auto",
      scale = 2,
    })

    -- Touchpad: no inverted scrolling, tap to click, 1/2/3 fingers = left/right/middle.
    hl.config({
      input = {
        touchpad = {
          natural_scroll = false,
          tap_button_map = "lrm",
          tap_to_click = true,
          clickfinger_behavior = true,
        },
      },
    })
  '';
}
