# nixPC — x86_64 workstation (Z370, single 4 TB USB NVMe, ZFS rpool).
{ config, lib, pkgs, ... }:

let
  # Newest kernel that the ZFS module supports: as up to date as possible
  # (Arch-like) without ever jumping ahead of ZFS.
  zfsCompatibleKernelPackages = lib.filterAttrs
    (name: kernelPackages:
      (builtins.match "linux_[0-9]+_[0-9]+" name) != null
      && (builtins.tryEval kernelPackages).success
      && (!kernelPackages.${config.boot.zfs.package.kernelModuleAttribute}.meta.broken))
    pkgs.linuxKernel.packages;
  latestZfsKernelPackages = lib.last (lib.sort
    (a: b: lib.versionOlder a.kernel.version b.kernel.version)
    (builtins.attrValues zfsCompatibleKernelPackages));
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # Monero node (monerod) + its blockchain storage mount.
    ./monero.nix
  ];

  boot.kernelPackages = latestZfsKernelPackages;

  boot.loader.efi.canTouchEfiVariables = true;

  my.zfs.pool = "rpool";

  # Hostname.
  networking.hostName = "nixPC";
  networking.hostId = "666ab666"; # Required by ZFS.

  # Steam + gaming stack (CS2 is native Linux).
  programs.steam.enable = true;
  programs.gamescope.enable = true; # Valve compositor; useful for fullscreen scaling on Hyprland.
  programs.gamemode.enable = true; # CPU governor / niceness tweaks while playing.

  hardware.graphics.enable32Bit = true; # Required for Steam's 32-bit runtime.

  # Wallpaper from the repo (hyprpaper + hyprlock).
  home-manager.users.andrew.my.wallpaper = "${../../wallpapers/space1.jpg}";
}
