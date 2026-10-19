{ config, lib, pkgs, nixpkgs, tbsm, ... }:

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
    slurp
    wl-clipboard
    grim
    sxiv
    gimp
    fzf
    ripgrep
    btop # Resource monitor.
    obs-studio
    kubectl
    #rustup # system-trusted CAs now work by setting CARGO_HTTP_PROXY_CAINFO - see rust-lang/cargo#15376 (closed).
    cargo # It works with devpeek proxy!
    rustfmt # Cargo formatter.
    rustc
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
    file
    monero-gui
    deno
    zed-editor
    parallel
    claude-code
    imagemagick
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
    # Not built for aarch64 (nixAir).
    tor-browser
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
    enable = true;
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

  imports = [
    ./options.nix
    ./waybar.nix
    ./hyprland.nix
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
      path = ${config.my.wallpaper}
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
          path = config.my.wallpaper;
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
