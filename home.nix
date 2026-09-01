{ config, pkgs, nixpkgs, tbsm, ... }:

{
  home.username = "andrew";
  home.homeDirectory = "/home/andrew";

  home.packages = with pkgs; [
    fastfetch
    #hyprland # We already have it in system packages...
    hyprpaper
    firefox
    brave
    wlsunset
    fzf
    lazygit
    gh # GitHub CLI.
    pwvucontrol
    keepassxc
    xeyes
    libnotify
    hack-font
    signal-desktop
    rclone
    hdrop # Script for guake/tilde like behavior for my floating terminal.
    slurp
    wl-clipboard
    grim
    sxiv
    gimp
    fzf
    ripgrep
    obs-studio
    kubectl
    #rustup <- It does NOT resolve system-trusted CAs - see rust-lang/cargo#15376.
    cargo # It works with devpeek proxy!
    buf # Required to compile `gevulot-rs`.
    protobuf # Required to compile `gevulot-rs`.
    mold # Modern linker.
    git-revise
    libreoffice
    kdePackages.okular
    kubernetes-helm
    kdePackages.ark
    sshfs
    difftastic
    tor-browser
    file
    monero-gui
    deno
    zed-editor
    parallel
    claude-code
    imagemagick
    bazecor
  ];

  programs.vscode = {
    enable = true;
    package = pkgs.vscode.fhs; # FHS required for CodeLLDB.
    profiles.default.extensions = with pkgs.vscode-extensions; [
      rust-lang.rust-analyzer
      vadimcn.vscode-lldb
      denoland.vscode-deno
    ];
  };

  home.stateVersion = "24.11";

  home.pointerCursor = {
    package = pkgs.phinger-cursors;
    name = "phinger-cursors-light";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  programs.alacritty = {
    enable = true;
    settings = {
      colors = {
        bright = {
          black = "#686868";
          blue = "#57c7ff";
          cyan = "#9aedfe";
          green = "#5af78e";
          magenta = "#ff6ac1";
          red = "#ff5c57";
          white = "#f1f1f0";
          yellow = "#f3f99d";
        };
        normal = {
          black = "#282a36";
          blue = "#57c7ff";
          cyan = "#9aedfe";
          green = "#5af78e";
          magenta = "#ff6ac1";
          red = "#ff5c57";
          white = "#f1f1f0";
          yellow = "#f3f99d";
        };
        primary = {
          background = "#282a36";
          foreground = "#eff0eb";
        };
      };
      font = {
        size = 12;
        bold = {
          family = "Hack";
          style = "Bold";
        };
        bold_italic = {
          family = "Hack";
          style = "Bold Italic";
        };
        italic = {
          family = "Hack";
          style = "Italic";
        };
        normal = {
          family = "Hack";
          style = "Regular";
        };
      };
      scrolling = {
        history = 10000;
      };
    };
  };

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.tmux = {
    enable = true;
    extraConfig = ''
      # https://github.com/seebi/tmux-colors-solarized/blob/master/tmuxcolors-256.conf
      set-option -g status-style fg=colour136,bg=colour235,default

      # set window split
      bind-key v split-window -h
      bind-key b split-window

      # The statusbar {

      set -g status-position bottom
      #bg=colour234
      set -g status-style fg=colour137,dim

      set -g status-left ""
      set -g status-right ""
      #set -g status-right 'avivace@e560 #[fg=colour233,bg=colour241,bold] %d/%m #[fg=colour233,bg=colour245,bold] %H:%M '
      set -g status-right-length 50
      set -g status-left-length 20

      setw -g window-status-current-style fg=colour81,bg=colour238,bold

      setw -g window-status-current-format ' #I#[fg=colour250]:#[fg=colour255]#W#[fg=colour50]#F '

      setw -g window-status-style fg=colour138,bg=colour235,none

      setw -g window-status-format ' #I#[fg=colour237]:#[fg=colour250]#W#[fg=colour244]#F '

      setw -g window-status-bell-style fg=colour255,bg=colour1,bold

      # pane border
      set -g pane-border-style fg=colour238,bg=colour235
      set -g pane-active-border-style fg=colour51,bg=colour236

      # The messages {

      set -g message-style fg=colour232,bg=colour166,bold
      set -g message-command-style fg=blue,bg=black

      # }

      # window mode
      setw -g mode-style fg=colour0,bg=colour6

      # pane number display
      set-option -g display-panes-active-colour colour33 #blue
      set-option -g display-panes-colour colour166 #orange

      # The modes {
      setw -g clock-mode-colour colour135
      setw -g mode-style fg=colour196,bg=colour238,bold
      # }

      # Old statusbar
      #set -g status-justify centre # center align window list
      #set -g status-left-length 20
      #set -g status-right-length 140
      #set -g status-left '#[fg=green]#H #[fg=black]• #[fg=green,bright]#(uname -r | cut -c 1-6)#[default]'
      #set -g status-right '#[fg=green,bg=default,bright]#(tmux-mem-cpu-load) #[fg=red,dim,bg=default]#(uptime | #cut -f 4-5 -d " " | cut -f 1 -d ",") #[fg=white,bg=default]%a%l:%M:%S %p#[default] #[fg=blue]%Y-%m-%d'

      # C-b is not acceptable -- Vim uses it
      unbind C-b
      set-option -g prefix C-a # ctrl+a for root session
      bind-key C-s send-prefix # ctrl+s for nested session

      # Remap some default keys
      unbind '"'
      bind 1 split-window -h -c "#{pane_current_path}"
      unbind %
      bind _ split-window -v -c "#{pane_current_path}"
      unbind c
      bind j new-window

      # Start numbering at 1
      set -g base-index 1

      # Allows for faster key repetition
      set -s escape-time 0

      # Rather than constraining window size to the maximum size of any client
      # connected to the *session*, constrain window size to the maximum size of any
      # client connected to *that window*. Much more reasonable.
      setw -g aggressive-resize on

      # Allows us to use C-a a <command> to send commands to a TMUX session inside
      # another TMUX session
      bind-key a send-prefix

      # Activity monitoring
      set-option -g visual-activity off
      set-option -g visual-bell off
      set-option -g visual-silence off
      set-w -g monitor-activity off
      set-option -g bell-action none

      # hjkl pane traversal
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # set to main-horizontal, 60% height for main pane
      bind m set-window-option main-pane-height 60\; select-layout main-horizontal

      bind-key J command-prompt -p "Name of new window: " "new-window -n '%%'"

      # reload config
      bind r source-file ~/.tmux.conf \; display-message "Config reloaded..."

      # auto window rename
      set-window-option -g automatic-rename

      # color
      set -g default-terminal "screen-256color"

      # https://github.com/edkolev/dots/blob/master/tmux.conf
      # Updates for tmux 1.9's current pane splitting paths.

      # from powerline
      run-shell "tmux set-environment -g TMUX_VERSION_MAJOR $(tmux -V | cut -d' ' -f2 | cut -d'.' -f1 | sed 's/[^0-9]*//g')"
      run-shell "tmux set-environment -g TMUX_VERSION_MINOR $(tmux -V | cut -d' ' -f2 | cut -d'.' -f2 | sed 's/[^0-9]*//g')"

      # Vi copypaste mode
      set-window-option -g mode-keys vi
      if-shell "test '\( #{$TMUX_VERSION_MAJOR} -eq 2 -a #{$TMUX_VERSION_MINOR} -ge 4 \)'" 'bind-key -Tcopy-mode-vi v send -X begin-selection; bind-key -Tcopy-mode-vi y send -X copy-selection-and-cancel'
      if-shell '\( #{$TMUX_VERSION_MAJOR} -eq 2 -a #{$TMUX_VERSION_MINOR} -lt 4\) -o #{$TMUX_VERSION_MAJOR} -le 1' 'bind-key -t vi-copy v begin-selection; bind-key -t vi-copy y copy-selection'

      # status bar
      if-shell '\( #{$TMUX_VERSION_MAJOR} -eq 2 -a #{$TMUX_VERSION_MINOR} -lt 2\) -o #{$TMUX_VERSION_MAJOR} -le 1' 'set-option -g status-utf8 on'

      # rm mouse mode fail
      if-shell '\( #{$TMUX_VERSION_MAJOR} -eq 2 -a #{$TMUX_VERSION_MINOR} -ge 1\)' 'set -g mouse off'
      if-shell '\( #{$TMUX_VERSION_MAJOR} -eq 2 -a #{$TMUX_VERSION_MINOR} -lt 1\) -o #{$TMUX_VERSION_MAJOR} -le 1' 'set -g mode-mouse off'

      # fix pane_current_path on new window and splits
      if-shell "test '#{$TMUX_VERSION_MAJOR} -gt 1 -o \( #{$TMUX_VERSION_MAJOR} -eq 1 -a #{$TMUX_VERSION_MINOR} -ge 8 \)'" 'unbind c; bind c new-window -c "#{pane_current_path}"'
      if-shell "test '#{$TMUX_VERSION_MAJOR} -gt 1 -o \( #{$TMUX_VERSION_MAJOR} -eq 1 -a #{$TMUX_VERSION_MINOR} -ge 8 \)'" "unbind '\"'; bind '\"' split-window -v -c '#{pane_current_path}'"
      if-shell "test '#{$TMUX_VERSION_MAJOR} -gt 1 -o \( #{$TMUX_VERSION_MAJOR} -eq 1 -a #{$TMUX_VERSION_MINOR} -ge 8 \)'" 'unbind v; bind v split-window -h -c "#{pane_current_path}"'
      if-shell "test '#{$TMUX_VERSION_MAJOR} -gt 1 -o \( #{$TMUX_VERSION_MAJOR} -eq 1 -a #{$TMUX_VERSION_MINOR} -ge 8 \)'" 'unbind \%; bind \% split-window -h -c "#{pane_current_path}"'

      # Lower repeat timeout
      set-option -g repeat-time 250

      #set-option -g default-shell "/bin/zsh"
    '';
  };

  programs = {
    zsh = {
      enable = true;
      enableCompletion = true;
      history.path = "$HOME/.local/state/zsh/.zsh_history";
      autosuggestion = {
        enable = false;
      };
      oh-my-zsh = {
        enable = true;
        plugins = [ "tmux" "kubectl" "fzf" ];
        theme = "robbyrussell";
      };
      sessionVariables = {
        ZSH_TMUX_AUTOSTART = "true";
        ZSH_TMUX_AUTOCONNECT = "false";
        FZF_DEFAULT_COMMAND = "rg";
      };
      shellAliases = {
        lg = "lazygit";
      };
    };
  };

  # Wayland notification daemon.
  services.mako = {
    enable = true;
  };

  # Helper for discovering nix packages.
  # NOTE: Does NOT seem to work...
  #programs.command-not-found.enable = true;

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

  imports = [
    ./waybar.nix
    tbsm.homeManagerModules.tbsm
    ./pixma-scan.nix # `pixma-scan <format> <resolution> <output>` scan helper.
    ./thunderbird.nix # Thunderbird + pre-configured kontakt@brosoft.xyz account.
    ./gpg-tools.nix # `gpg-load` + `tgpg`: KeePass-backed RAM-only GPG keyring.
  ];
  tbsm = {
    enable = true;
    defaultSession = "Hyprland";
    sessions = [
      {
        Name = "Hyprland";
        Comment = "An intelligent dynamic tiling Wayland compositor";
        Exec = "${pkgs.hyprland}/bin/start-hyprland";
        Type = "Application";
        DesktopNames = "Hyprland";
        Keywords = "tiling;wayland;compositor;";
      }
    ];
  };

  #fonts.fontconfig.enable = true;

  home.file.".config/hypr/hyprpaper.conf".text = ''
    splash = false
    ipc = on

    wallpaper {
      monitor =
      path = ${config.home.homeDirectory}/Downloads/wallpaper.jpg
    }
  '';

  programs.git = {
    enable = true;
    settings.user = {
      email = "andrzej1_1@o2.pl";
      name = "Andrzej Broński";
    };
    signing.key = "BF713D7A7BCEF5DC"; # personal default (andrzej1_1@o2.pl / koxu1996@gmail.com)
    signing.signByDefault = true; # Auto-sign every commit (commit.gpgsign).

    # P11 work identity: auto-switch email + signing key for any repo whose path
    # starts with ~/Downloads/tmp/p11 (e.g. p11-pillar-v0). Personal identity
    # stays the default everywhere else.
    includes = [
      {
        condition = "gitdir:~/Downloads/tmp/p11*/";
        contents = {
          user.email = "ab@projecteleven.com";
          user.signingkey = "6550D9BB6997F292F57A861802963296A5FABF6D";
        };
      }
    ];

    # We want to have `gitk` tool.
    package = pkgs.gitFull;
  };

  # GPG + agent so the signing key's passphrase can be entered and cached.
  # Without a pinentry, both `gpg --import` and commit signing fail with
  # "No pinentry". pinentry-qt is a GUI popup that also works inside lazygit
  # (Qt is already in the closure via KeePassXC).
  programs.gpg.enable = true;
  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-qt;
    defaultCacheTtl = 28800; # 8h — don't retype the passphrase every commit.
    maxCacheTtl = 28800;
  };

  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
      };
      animations.enabled = false;
      background = [
        {
          monitor = "";
          path = "/home/andrew/Downloads/wallpaper.jpg";
          blur_passes = 2; # 0 disables blurring
          blur_size = 7;
          noise = 1.17e-2;
        }
      ];
      input-field = {
        monitor = "";
        size = "200,50";
        outline_thickness = 2;
        dots_size = 0.2; # Scale of input-field height, 0.2 - 0.8
        dots_spacing = 0.35; # Scale of dots' absolute size, 0.0 - 1.0
        dots_center = true;
        outer_color = "rgba(0, 0, 0, 0)";
        inner_color = "rgba(0, 0, 0, 0.2)";
        font_color = "rgb(111, 45, 104)";
        fade_on_empty = false;
        rounding = -1;
        check_color = "rgb(30, 107, 204)";
        placeholder_text = ''<i><span foreground="##cdd6f4">Input Password...</span></i>'';
        hide_input = false;
        position = "0, -100";
        halign = "center";
        valign = "center";
      };
    };
  };
}
