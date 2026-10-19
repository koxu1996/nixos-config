# nixAir — MacBook Air M2 13" (2022), aarch64, NixOS next to macOS and Arch on
# the internal disk. ZFS pool `mpool` on one partition (see disko.nix).
{ config, lib, ... }:

let
  zfsModule = config.boot.kernelPackages.${config.boot.zfs.package.kernelModuleAttribute};
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  hardware.asahi.enable = true;

  # Apple's peripheral firmware (Wi-Fi, webcam, ...) from the ESP the Asahi
  # installer filled. It is non-redistributable and never committed, so nixAir
  # is always built with `--impure`. /boot/efi/vendorfw is the Arch install's
  # ESP on this same Mac (identical firmware), used when building from Arch.
  hardware.asahi.peripheralFirmwareDirectory = lib.findFirst
    (dir: builtins.pathExists (dir + "/firmware.cpio"))
    (throw "nixAir: no vendorfw/firmware.cpio found - build with --impure on the Mac")
    [ /boot/vendorfw /mnt/boot/vendorfw /boot/efi/vendorfw ];

  # Kernel (linux-asahi) comes from nixos-apple-silicon; ZFS must support it.
  boot.supportedFilesystems.zfs = true;
  assertions = [
    {
      assertion = !(zfsModule.meta.broken or false);
      message = "ZFS ${config.boot.zfs.package.version} does not support the Asahi kernel ${config.boot.kernelPackages.kernel.version}; keep the previous nixos-apple-silicon lock until ZFS catches up.";
    }
  ];

  # U-Boot provides EFI, but Apple's boot policy can't be changed from Linux.
  boot.loader.efi.canTouchEfiVariables = false;

  my.zfs.pool = "mpool";

  # Hostname.
  networking.hostName = "nixAir";
  networking.hostId = "a35dc981"; # Required by ZFS.

  # Wi-Fi via iwd (`iwctl`), with iwd's own DHCP client.
  networking.wireless.iwd = {
    enable = true;
    settings.General.EnableNetworkConfiguration = true;
  };
  environment.persistence."/persist".directories = [
    "/var/lib/iwd" # Known networks + passphrases.
  ];

  # Laptop: battery state for the bar and power tools.
  services.upower.enable = true;

  home-manager.users.andrew.imports = [ ./home.nix ];
}
