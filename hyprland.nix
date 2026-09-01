# Hyprland window manager — split out of home.nix.
{ pkgs, lib, config, ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;
    # Keep the legacy hyprlang config format (your settings are hyprlang, not lua).
    configType = "hyprlang";
    plugins = [
      # Proper i3-like tilling.
      pkgs.hyprlandPlugins.hy3
    ];
    settings = {
      ###################
      ### ENVIRONMENT ###
      ###################

      # Trying to fix broken screen sharing...
      # See https://wiki.hyprland.org/Configuring/Environment-variables/#xdg-specifications.
      #env = [
      #  "XDG_CURRENT_DESKTOP,Hyprland"
      #  "XDG_SESSION_TYPE,wayland"
      #  "XDG_SESSION_DESKTOP,Hyprland"
      #];

      env = [
        "XCURSOR_THEME,phinger-cursors-light"
        "XCURSOR_SIZE,24"
      ];

      #################
      ### VARIABLES ###
      #################

      # Keycodes (unviresal for all layouts)
      # Note: they were obtained with *xmodmap*, you might add
      # more if something is not listed here.
      "$keycode_Escape" = 9;
      "$keycode_1" = 10;
      "$keycode_2" = 11;
      "$keycode_3" = 12;
      "$keycode_4" = 13;
      "$keycode_5" = 14;
      "$keycode_6" = 15;
      "$keycode_7" = 16;
      "$keycode_8" = 17;
      "$keycode_9" = 18;
      "$keycode_0" = 19;
      "$keycode_minus" = 20;
      "$keycode_plus" = 21;
      "$keycode_BackSpace" = 22;
      "$keycode_q" = 24;
      "$keycode_w" = 25;
      "$keycode_e" = 26;
      "$keycode_r" = 27;
      "$keycode_t" = 28;
      "$keycode_y" = 29;
      "$keycode_u" = 30;
      "$keycode_i" = 31;
      "$keycode_o" = 32;
      "$keycode_p" = 33;
      "$keycode_Return" = 36;
      "$keycode_Control_L" = 37;
      "$keycode_a" = 38;
      "$keycode_s" = 39;
      "$keycode_d" = 40;
      "$keycode_f" = 41;
      "$keycode_g" = 42;
      "$keycode_h" = 43;
      "$keycode_j" = 44;
      "$keycode_k" = 45;
      "$keycode_l" = 46;
      "$keycode_grave" = 49;
      "$keycode_z" = 52;
      "$keycode_x" = 53;
      "$keycode_c" = 54;
      "$keycode_v" = 55;
      "$keycode_b" = 56;
      "$keycode_n" = 57;
      "$keycode_m" = 58;
      "$keycode_Space" = 65;
      "$keycode_Print" = 107;
      "$keycode_Home" = 110;
      "$keycode_Up" = 111;
      "$keycode_Prior" = 112;
      "$keycode_Left" = 113;
      "$keycode_Right" = 114;
      "$keycode_End" = 115;
      "$keycode_Down" = 116;
      "$keycode_Next" = 117;

      ###################
      ### MY PROGRAMS ###
      ###################

      # See https://wiki.hyprland.org/Configuring/Keywords/

      # Preferred terminal emulator
      "$terminal" = "${pkgs.alacritty}/bin/alacritty";

      # Application launcher
      "$launcher" = ''
        alacritty --title="Application launcher - System" -e "bash" "-c" "compgen -c | sort -u | fzf | xargs hyprctl dispatch exec --"
      '';

      #################
      ### AUTOSTART ###
      #################

      exec-once = [
        # NOTE: waybar is started as a systemd user service (programs.waybar.systemd.enable), not here.
        # Launch night-light filter.
        "wlsunset -l 55.7:12.6 -t 5600:3600 -g 0.8"
        # Launch wallpaper.
        "hyprpaper"
      ];

      #####################
      ### LOOK AND FEEL ###
      #####################

      # https://wiki.hyprland.org/Configuring/Variables/#general
      general = {
        #gaps_in = 5;
        #gaps_out = 20;

        # Make window border bolder.
        border_size = 2;

        # Green-orange border for active window.
        "col.active_border" = "rgba(33fe9cee) rgba(fe8d33ee) 45deg";

        # Use hy3 plugin layout.
        layout = "hy3";
      };

      # https://wiki.hyprland.org/Configuring/Variables/#misc
      misc = {
        # Disable fucking anime mascot.
        force_default_wallpaper = 0;

        # No weird slogans on desktop.
        disable_splash_rendering = true;
      };

      # https://wiki.hyprland.org/Configuring/Variables/#decoration
      decoration = {
        # Minor rounding around windows.
        rounding = 4;
      };

      # https://wiki.hyprland.org/Configuring/Variables/#animations
      animations = {
        enabled = false; # All animations are just an unnecessary slowdown.
        animation = [
          # Disable all workspaces animations.
          "workspaces, 0"
        ];
      };

      cursor = {
        enable_hyprcursor = false;
        no_warps = true; # Prevent jumping to the focused window e.g. floating terminal.
        no_hardware_cursors = true; # Fixes locked/stuck cursor in CS2 and other XWayland games.
      };

      #############
      ### INPUT ###
      #############

      # https://wiki.hyprland.org/Configuring/Variables/#input
      input = {
        # Layout:
        # - PL, Dvorak programmer (dvp)
        # NOTE: For traditional PL qwerty, use 'legacy' variant.
        kb_layout = "pl";
        kb_variant = "dvp";
        kb_options = [
          "caps:shiflock" # I want CapsLock to affect numbers row.
        ];

        # Cursor focus detatched from keyboard focus.
        follow_mouse = 2;

        # Prevent automatic focus switch when hovering a window under the floating one.
        float_switch_override_focus = false;
      };

      ###################
      ### KEYBINDINGS ###
      ###################

      # See https://wiki.hyprland.org/Configuring/Keywords/
      "$mainMod" = "ALT"; # Sets "ALT" key as main modifier
      "$sup" = "SUPER";

      # https://wiki.hyprland.org/Configuring/Binds/

      bind = [
        # Exit compositor on mainMod + SHIFT + e.
        "$mainMod SHIFT, $keycode_e, exit"

        # Open launcher with mainMod + d.
        "$mainMod, $keycode_d, exec, $launcher"

        # Toggle floating terminal with $.
        ", $keycode_grave, exec, hdrop alacritty --class floating_terminal_1"

        # Launch lockscreen with sup + L.
        "$sup, $keycode_l, exec, hyprlock"

        # Make the current focus fullscreen with mainMod + f.
        "$mainMod, $keycode_f, fullscreen"

        # Toggle floating mode of focused window with mainMod + SHIFT + Space.
        "$mainMod SHIFT, $keycode_Space, togglefloating"

        # Kill focused window with mainMod + SHIFT + q.
        "$mainMod SHIFT, $keycode_q, killactive"

        # Move focus with mainMod + arrow keys.
        "$mainMod, $keycode_h, hy3:movefocus, l"
        "$mainMod, $keycode_j, hy3:movefocus, d"
        "$mainMod, $keycode_k, hy3:movefocus, u"
        "$mainMod, $keycode_l, hy3:movefocus, r"

        # Move window mainMod + SHIFT + h/j/k/l.
        "$mainMod SHIFT, $keycode_h, hy3:movewindow, l"
        "$mainMod SHIFT, $keycode_j, hy3:movewindow, d"
        "$mainMod SHIFT, $keycode_k, hy3:movewindow, u"
        "$mainMod SHIFT, $keycode_l, hy3:movewindow, r"

        # Switch workspaces with mainMod + [0-9].
        "$mainMod, $keycode_1, workspace, 1"
        "$mainMod, $keycode_2, workspace, 2"
        "$mainMod, $keycode_3, workspace, 3"
        "$mainMod, $keycode_4, workspace, 4"
        "$mainMod, $keycode_5, workspace, 5"
        "$mainMod, $keycode_6, workspace, 6"
        "$mainMod, $keycode_7, workspace, 7"
        "$mainMod, $keycode_8, workspace, 8"
        "$mainMod, $keycode_9, workspace, 9"
        "$mainMod, $keycode_0, workspace, 10"

        # Move active window to a workspace with mainMod + SHIFT + [0-9].
        "$mainMod SHIFT, $keycode_1, movetoworkspacesilent, 1"
        "$mainMod SHIFT, $keycode_2, movetoworkspacesilent, 2"
        "$mainMod SHIFT, $keycode_3, movetoworkspacesilent, 3"
        "$mainMod SHIFT, $keycode_4, movetoworkspacesilent, 4"
        "$mainMod SHIFT, $keycode_5, movetoworkspacesilent, 5"
        "$mainMod SHIFT, $keycode_6, movetoworkspacesilent, 6"
        "$mainMod SHIFT, $keycode_7, movetoworkspacesilent, 7"
        "$mainMod SHIFT, $keycode_8, movetoworkspacesilent, 8"
        "$mainMod SHIFT, $keycode_9, movetoworkspacesilent, 9"
        "$mainMod SHIFT, $keycode_0, movetoworkspacesilent, 10"

        # Start terminal with mainMod + Enter.
        "$mainMod, code:$keycode_Return, exec, $terminal"

        # Partial screenshot to clipboard with Left Alt + Print Screen.
        "ALT_L, code:$keycode_Print, exec, grim -g \"$(slurp)\" - | wl-copy"

        # Full screenshot to files with Print Screen.
        ", code:$keycode_Print, exec, grim -c ~/screenshot_$(date +'%Y-%m-%d_%H-%M-%S').png"
      ];

      # Allowed to work when screen is locked.
      bindel = [
        # Volume bindings.
        "SHIFT, $keycode_Next, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
        "SHIFT, $keycode_Prior, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        "SHIFT, $keycode_Home, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        "SHIFT, $keycode_End, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
      ];

      # Mouse bindings.
      bindm = [
        # Move window with mainMod + LBM.
        "$mainMod, mouse:272, movewindow" # NOTE: hy3:movewindow is broken for floating windows.
        # Move window with mainMod + RBM.
        "$mainMod, mouse:273, resizewindow"
      ];

      ##############################
      ### WINDOWS AND WORKSPACES ###
      ##############################

      # See https://wiki.hyprland.org/Configuring/Window-Rules/ for more
      # See https://wiki.hyprland.org/Configuring/Workspace-Rules/ for workspace rules

      windowrule = [
        # Floating launcher.
        "match:title (Application launcher - System), float on"

        # Floating terminal.
        "match:class floating_terminal_1, float on"
        "match:class floating_terminal_1, size monitor_w*0.7 monitor_h*0.35"
        "match:class floating_terminal_1, move monitor_w*0.15 monitor_h*0.6"
      ];

      #########################
      ### HYPRLAND SPECIFIC ###
      #########################
      ecosystem = {
        no_update_news = true; # Prevent popup on Hyprland update.
      };
    };
    systemd = {
      enable = true;
    };
  };
}
