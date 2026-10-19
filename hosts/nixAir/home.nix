# nixAir-only Home Manager settings: built-in Retina panel, touchpad, function row.
{ lib, pkgs, ... }:

{
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

    -- MacBook function row (no Print key, no keyboard-backlight keys on the M2 Air).
    local laptopKey = { locked = true, repeating = true }
    hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), laptopKey)
    hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), laptopKey)
    hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), laptopKey)
    hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), laptopKey)
    hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
    hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
    hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

    -- No Print key: region screenshot to clipboard with mainMod + SHIFT + s.
    hl.bind(key(mainMod .. " + SHIFT", "s"), hl.dsp.exec_cmd([[grim -g "$(slurp)" - | wl-copy]]))

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

  home.packages = [ pkgs.brightnessctl pkgs.playerctl ];

  # Battery in the bar (laptop only).
  programs.waybar.settings.mainBar.modules-right = lib.mkAfter [ "battery" ];
}
