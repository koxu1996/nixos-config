# Waybar status bar — split out of home.nix.
{ pkgs, lib, ... }:
{
  programs.waybar = {
    enable = true;
    # Run waybar as a systemd user service (bound to graphical-session.target)
    # instead of a Hyprland exec-once. It then auto-restarts on crash and is
    # restarted by `nixos-rebuild switch`, so a waybar version bump no longer
    # leaves a dead bar. (The exec-once launch is removed below accordingly.)
    systemd.enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        modules-left = [
          "hyprland/workspaces"
          "hyprland/submap"
        ];
        modules-center = [
          "hyprland/window"
        ];
        modules-right = [
          "custom/voice"
          "pulseaudio"
          "network"
          "cpu"
          "memory"
          "clock"
          "tray"
        ];
        "hyprland/workspaces" = {
          all-outputs = true;
          format = "{name}: {icon}";
          format-icons = {
            "1" = "";
            "2" = "";
            "3" = "";
            "4" = "";
            "5" = "";
            active = "";
            default = "";
          };
        };
        "hyprland/mode" = {
          format = "<span style=\"italic\">{}</span>";
        };
        tray = {
          #spacing = 10;
        };
        clock = {
          format = "{:%d-%m-%Y  %H:%M}";
          tooltip = false;
        };
        cpu = {
          format = "{usage}% ";
          tooltip = false;
        };
        memory = {
          format = "{}% ";
          tooltip = false;
        };
        network = {
          "format-wifi" = "{essid} ({signalStrength}%) ";
          "format-ethernet" = "{ifname}: {ipaddr}/{cidr} ";
          "format-linked" = "{ifname} (No IP) ";
          "format-disconnected" = "Disconnected ⚠";
          tooltip = false;
        };
        pulseaudio = {
          "scroll-step" = 0.0; # Disable scroll.
          format = "{volume}% {icon} {format_source}";
          "format-bluetooth" = "{volume}% {icon} {format_source}";
          "format-muted" = " {format_source}";
          "format-source" = "{volume}% ";
          "format-source-muted" = "";
          "format-icons" = {
            headphones = "";
            handsfree = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [ "" "" "" ];
          };
          "on-click" = "pwvucontrol";
          tooltip = false;
        };
        "custom/voice" = {
          exec = "voice status";
          "return-type" = "json";
          interval = 1;
          "on-click" = "voice toggle";         # left: start/stop recording
          "on-click-right" = "voice settings"; # right: open settings
          tooltip = true;
        };
      };
    };
    style = ''
      * {
        /* `font-awesome` is required to be installed for icons */
        font-family: Roboto, Helvetica, Arial, sans-serif, "Font Awesome 7 Free", "Font Awesome 7 Brands";
        font-size: 13px;
      }
      #custom-voice { padding: 0 10px; }
      #custom-voice.idle { color: #cdd6f4; }
      #custom-voice.recording { color: #f38ba8; }
      #custom-voice.processing { color: #89b4fa; }
      #custom-voice.off { color: #6c7086; }
      window#waybar {
        background-color: rgba(43, 48, 59, 0.5);
        border-bottom: 3px solid rgba(100, 114, 125, 0.5);
        color: #ffffff;
        transition-property: background-color;
        transition-duration: .5s;
      }
      window#waybar.hidden {
        opacity: 0.2;
      }
      /*
      window#waybar.empty {
        background-color: transparent;
      }
      window#waybar.solo {
        background-color: #FFFFFF;
      }
      */
      window#waybar.termite {
        background-color: #3F3F3F;
      }
      window#waybar.chromium {
        background-color: #000000;
        border: none;
      }
      button {
        /* Use box-shadow instead of border so the text isn't offset */
        box-shadow: inset 0 -3px transparent;
        /* Avoid rounded borders under each button name */
        border: none;
        border-radius: 0;
      }
      /* https://github.com/Alexays/Waybar/wiki/FAQ#the-workspace-buttons-have-a-strange-hover-effect */
      button:hover {
        background: inherit;
        box-shadow: inset 0 -3px #ffffff;
      }
      /* you can set a style on hover for any module like this */
      #pulseaudio:hover {
        background-color: #a37800;
      }
      #workspaces button {
        padding: 0 5px;
        background-color: transparent;
        color: #ffffff;
      }
      #workspaces button:hover {
        background: rgba(0, 0, 0, 0.2);
      }
      #workspaces button.focused,
      #workspaces button.active /* See https://github.com/Alexays/Waybar/issues/2151. */
      {
        background-color: #64727D;
        box-shadow: inset 0 -3px #ffffff;
      }
      #workspaces button.active {
        background-color: #64727D;
        box-shadow: inset 0 -3px #ffffff;
      }
      #workspaces button.urgent {
        background-color: #eb4d4b;
      }
      #mode {
        background-color: #64727D;
        box-shadow: inset 0 -3px #ffffff;
      }
      #clock,
      #battery,
      #cpu,
      #memory,
      #disk,
      #temperature,
      #backlight,
      #network,
      #pulseaudio,
      #wireplumber,
      #custom-media,
      #tray,
      #mode,
      #idle_inhibitor,
      #scratchpad,
      #power-profiles-daemon,
      #mpd {
        padding: 0 10px;
        margin: 0 4px; /* AB: I want to separate each module. */
        color: #ffffff;
      }
      #window,
      #workspaces {
        margin: 0 4px;
      }
      /* If workspaces is the leftmost module, omit left margin */
      .modules-left > widget:first-child > #workspaces {
        margin-left: 0;
      }
      /* If workspaces is the rightmost module, omit right margin */
      .modules-right > widget:last-child > #workspaces {
        margin-right: 0;
      }
      #clock {
        background-color: #64727D;
      }
      #battery {
        background-color: #ffffff;
        color: #000000;
      }
      #battery.charging, #battery.plugged {
        color: #ffffff;
        background-color: #26A65B;
      }
      @keyframes blink {
        to {
          background-color: #ffffff;
          color: #000000;
        }
      }
      /* Using steps() instead of linear as a timing function to limit cpu usage */
      #battery.critical:not(.charging) {
        background-color: #f53c3c;
        color: #ffffff;
        animation-name: blink;
        animation-duration: 0.5s;
        animation-timing-function: steps(12);
        animation-iteration-count: infinite;
        animation-direction: alternate;
      }
      #power-profiles-daemon {
        padding-right: 15px;
      }
      #power-profiles-daemon.performance {
        background-color: #f53c3c;
        color: #ffffff;
      }
      #power-profiles-daemon.balanced {
        background-color: #2980b9;
        color: #ffffff;
      }
      #power-profiles-daemon.power-saver {
        background-color: #2ecc71;
        color: #000000;
      }
      label:focus {
        background-color: #000000;
      }
      #cpu {
        background-color: #2ecc71;
        color: #000000;
      }
      #memory {
        background-color: #9b59b6;
      }
      #disk {
        background-color: #964B00;
      }
      #backlight {
        background-color: #90b1b1;
      }
      #network {
        background-color: #2980b9;
      }
      #network.disconnected {
        background-color: #f53c3c;
      }
      #pulseaudio {
        background-color: #f1c40f;
        color: #000000;
      }
      #pulseaudio.muted {
        background-color: #90b1b1;
        color: #2a5c45;
      }
      #wireplumber {
        background-color: #fff0f5;
        color: #000000;
      }
      #wireplumber.muted {
        background-color: #f53c3c;
      }
      #custom-media {
        background-color: #66cc99;
        color: #2a5c45;
        min-width: 100px;
      }
      #custom-media.custom-spotify {
        background-color: #66cc99;
      }
      #custom-media.custom-vlc {
        background-color: #ffa000;
      }
      #temperature {
        background-color: #f0932b;
      }
      #temperature.critical {
        background-color: #eb4d4b;
      }
      #tray {
        background-color: #2980b9;
      }
      #tray > .passive {
        -gtk-icon-effect: dim;
      }
      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
        background-color: #eb4d4b;
      }
      #idle_inhibitor {
        background-color: #2d3436;
      }
      #idle_inhibitor.activated {
        background-color: #ecf0f1;
        color: #2d3436;
      }
      #mpd {
        background-color: #66cc99;
        color: #2a5c45;
      }
      #mpd.disconnected {
        background-color: #f53c3c;
      }
      #mpd.stopped {
        background-color: #90b1b1;
      }
      #mpd.paused {
        background-color: #51a37a;
      }
      #language {
        background: #00b093;
        color: #740864;
        padding: 0 5px;
        margin: 0 5px;
        min-width: 16px;
      }
      #keyboard-state {
        background: #97e1ad;
        color: #000000;
        padding: 0 0px;
        margin: 0 5px;
        min-width: 16px;
      }
      #keyboard-state > label {
        padding: 0 5px;
      }
      #keyboard-state > label.locked {
        background: rgba(0, 0, 0, 0.2);
      }
      #scratchpad {
        background: rgba(0, 0, 0, 0.2);
      }
      #scratchpad.empty {
        background-color: transparent;
      }
      #privacy {
        padding: 0;
      }
      #privacy-item {
        padding: 0 5px;
        color: white;
      }
      #privacy-item.screenshare {
        background-color: #cf5700;
      }
      #privacy-item.audio-in {
        background-color: #1ca000;
      }
      #privacy-item.audio-out {
        background-color: #0069d4;
      }
    '';
  };
}
