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

  # OpenCode 2 installs itself here (curl -fsSL https://opencode.ai/v2/install | bash)
  home.sessionPath = [ "$HOME/.opencode/bin" ];

  home.pointerCursor = {
    enable = true;
    package = pkgs.phinger-cursors;
    name = "phinger-cursors-light";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;

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

  # Helper for discovering nix packages.
  # NOTE: Does NOT seem to work...
  #programs.command-not-found.enable = true;

  imports = [
    ./options.nix
    ./look
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
