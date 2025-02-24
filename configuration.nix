# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      # Persistence config.
      ./persist.nix
    ];

  # I would like to use the latest kernel - ArchOS like experience - but ZFS
  # is NOT compatible...
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Clear old temporary files on boot.
  boot.tmp.cleanOnBoot = true;

  # Rollback root dataset on boot.
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    zfs rollback -r rpool/local/root@blank
  '';

  # Hostname.
  networking.hostName = "nixPC";
  networking.hostId = "666ab666"; # Required by ZFS.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Timezone.
  time.timeZone = "Europe/Warsaw";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  console = {
    #   font = "Lat2-Terminus16";
    #keyMap = "dvorak-programmer";
    useXkbConfig = true; # use xkb.options in tty.
  };

  # Allow unfree software like VSCode.
  nixpkgs.config.allowUnfree = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Disable default display manager (lightdm).
  # NOTE: It requires enabling the dummy "startx" pseudo-display manager.
  services.xserver.displayManager.startx.enable = true;

  # Configure keymap in X11
  services.xserver.xkb.layout = "pl";
  services.xserver.xkb.variant = "dvp";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # Enable RealtimeKit service for low-latency audio.
  security.rtkit.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Do NOT allow mutation of users outside of the config.
  users.mutableUsers = false;

  # Root and user accounts.
  users.users.root.initialPassword = "pass";
  users.users.andrew = {
    isNormalUser = true;
    initialPassword = "pass";
    extraGroups = [
      "wheel" # Enable ‘sudo’ for the user.
      "docker"
      #"video"
      #"audio"
    ];
    packages = with pkgs; [
      tree
    ];
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;

  # IMPORTANT: Polkit must be enabled, otherwise Hyprland (or other Wayland sessions) will be unable to start.
  security.polkit.enable = true;

  # Do NOT lecture the sudo user. Less mutable state.
  security.sudo.extraConfig = ''
    Defaults lecture = never
  '';

  # programs.firefox.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  # environment.systemPackages = with pkgs; [
  #   vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #   wget
  # ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Disable the default firewall.
  networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.11"; # Did you read the comment?

  # Enable the Flakes feature and the accompanying new nix command-line tool.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  environment.systemPackages = with pkgs; [
    # Flakes clones its dependencies through the git command, so git must be installed first.
    git
    vim
    wget
    pciutils
    util-linux # dmesg
    openssl
    pkg-config
    clang
  ];

  # Add OpenSSL path to additional pkgconfig paths.
  environment.variables = {
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
  };

  # Configure XDG portal - it fixes screen sharing in Hyprland.
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
    ];
    config = {
      common = {
        default = [
          "hyprland"
        ];
      };
    };
  };

  # Hyperland desktop.
  #programs.hyprland.enable = true;

  hardware.graphics = {
    enable = true;
  };

  # Custom issue "greeter".
  environment.etc.issue.text = ''
    [0m[34m          ::::.    [0m[36m':::::     ::::'
    [0m[34m          ':::::    [0m[36m':::::.  ::::'
    [0m[34m            :::::     [0m[36m'::::.:::::
    [0m[34m      .......:::::..... [0m[36m::::::::
    [0m[34m     ::::::::::::::::::. [0m[36m::::::    [0m[34m::::.
        ::::::::::::::::::::: [0m[36m:::::.  [0m[34m.::::'
    [0m[36m           .....           ::::' [0m[34m:::::'
    [0m[36m          :::::            '::' [0m[34m:::::'
    [0m[36m ........:::::               ' [0m[34m:::::::::::.
    [0m[36m:::::::::::::                 [0m[34m:::::::::::::
    [0m[36m ::::::::::: [0m[34m..              [0m[34m:::::
    [0m[36m     .::::: [0m[34m.:::            [0m[34m:::::
    [0m[36m    .:::::  [0m[34m:::::          [0m[34m\'\'\'\'\'    [0m[36m.....
        :::::   [0m[34m':::::.  [0m[36m......:::::::::::::'
         :::     [0m[34m::::::. [0m[36m':::::::::::::::::'
    [0m[34m            .:::::::: [0m[36m'::::::::::
    [0m[34m           .::::\'\'::::.     [0m[36m'::::.
    [0m[34m          .::::'   ::::.     [0m[36m'::::.
    [0m[34m         .::::      ::::      [0m[36m'::::.

    [0m[0m  Welcome to \n on [0m[1m[37m\l[0m[0m. Today is \d
    [0m
  '';

  # Enable Wayland ozone platform for Chromium and Electron based apps.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  fonts.packages = with pkgs; [
    font-awesome
  ];

  # Enable Docker.
  virtualisation.docker.enable = true;
}
