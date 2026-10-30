# nuc — headless x86_64 server on the home LAN, idle for now (waiting for work).
# Lean on purpose: none of the desktop (modules/base.nix, home-manager, Hyprland).
# Shares the ZFS impermanence (modules/zfs-impermanence.nix) and SSH (modules/ssh.nix)
# setup with the laptops. Installed with nixos-anywhere, see ./README.md.
{ lib, pkgs, ... }:

{
  imports = [
    ./disko.nix
    ../../modules/zfs-impermanence.nix
  ];

  # Hardware (drivers, CPU microcode, firmware) from the nixos-facter scan taken in the
  # installer, instead of a hand-kept hardware-configuration.nix.
  hardware.facter.reportPath = lib.mkIf (builtins.pathExists ./facter.json) ./facter.json;

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems.zfs = true;
  boot.tmp.cleanOnBoot = true;

  my.zfs.pool = "rpool";
  fileSystems."/persist".neededForBoot = true;

  networking.hostName = "nuc";
  networking.hostId = "cccb429e"; # Required by ZFS.

  # Firewall on (unlike the laptops): this box sits on the LAN. Tailscale is trusted,
  # and SSH is also open on the LAN (see below).
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
    allowedTCPPorts = [ 22 ];
  };

  # SSH from the LAN as well as Tailscale (modules/ssh.nix allows only Tailscale): the
  # only way in until `sudo tailscale up`, and the fallback if Tailscale logs out
  # again. Keys only, as everywhere.
  services.openssh.settings.AllowUsers = lib.mkForce [
    "andrew@100.64.0.0/10"
    "andrew@fd7a:115c:a1e0::/48"
    "andrew@192.168.1.0/24"
  ];

  services.tailscale.enable = true;

  # No passwords at all: root is locked, andrew logs in with the SSH key only and
  # sudo doesn't ask (as on nixvps). The console offers no login.
  users.mutableUsers = false;
  users.users.root.hashedPassword = "!";
  users.users.andrew = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    hashedPassword = "!";
  };
  security.sudo.wheelNeedsPassword = false;

  # Same as the laptops (modules/base.nix): zram swap, earlyoom before the kernel OOM killer.
  zramSwap.enable = true;
  services.earlyoom.enable = true;

  time.timeZone = "Europe/Warsaw";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "@wheel" ]; # Deploys from the laptops (nixos-rebuild --target-host).
  nix.channel.enable = false;

  environment.systemPackages = with pkgs; [ git vim htop ];

  # What survives the root rollback. SSH's host key is already on /persist (modules/ssh.nix);
  # it and /persist/etc/machine-id are seeded at install time (README.md).
  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/nixos" # uid/gid map.
      "/var/lib/tailscale" # Node key: no re-login after reboot.
      "/var/lib/systemd" # Timers' last run, random seed.
    ];
    files = [ "/etc/machine-id" ];
    users.andrew.directories = [
      { directory = ".ssh"; mode = "0700"; }
    ];
  };

  system.stateVersion = "26.11";
}
