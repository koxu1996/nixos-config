# nixAir — MacBook Air M2 13" (2022), aarch64, NixOS next to macOS and Arch on
# the internal disk. ZFS pool `mpool` on one partition (see disko.nix).
{ config, lib, pkgs, ... }:

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

  # Swap Cmd and Option in the internal keyboard's driver: Cmd sends Alt (the
  # Hyprland main key, and Alt+Backspace etc. in every app and the TTY),
  # Option sends Super. Applies from the first keystroke, no remapping daemon.
  boot.extraModprobeConfig = "options hid_apple swap_opt_cmd=1";

  # Show the real notch area (1280x832 logical; the bar sits beside it, see
  # my.look.notchGap) and the Wi-Fi driver quirk the Arch install boots with.
  boot.kernelParams = [ "appledrm.show_notch=1" "brcmfmac.feature_disable=0x82000" ];

  # NixOS snowflake instead of the Asahi logo on the m1n1 boot screen. The
  # boot-picker icon and name live in the macOS stub volume and can only be
  # changed from macOS; nixos-icon.png on the ESP is the source image for that
  # (convert it on macOS with `sips -s format icns`).
  boot.m1n1CustomLogo = "${pkgs.nixos-icons}/share/icons/hicolor/256x256/apps/nix-snowflake.png";
  boot.loader.systemd-boot.extraFiles."nixos-icon.png" =
    "${pkgs.nixos-icons}/share/icons/hicolor/512x512/apps/nix-snowflake.png";

  # U-Boot provides EFI, but Apple's boot policy can't be changed from Linux.
  boot.loader.efi.canTouchEfiVariables = false;
  # The ESP the Asahi installer made is only 477 MB and each generation with a
  # new kernel/initrd takes ~100 MB of it.
  boot.loader.systemd-boot.configurationLimit = 3;

  # CPU profiles for the bar (Apple M2).
  my.cpuProfile.script = ./cpu-profile;

  my.zfs.pool = "mpool";

  # Hostname.
  networking.hostName = "nixAir";
  networking.hostId = "a35dc981"; # Required by ZFS.

  # Wi-Fi via iwd (`iwctl`), with iwd's own DHCP client - so no dhcpcd,
  # which would otherwise also manage wlan0.
  networking.useDHCP = false;
  networking.dhcpcd.enable = false;
  networking.wireless.iwd = {
    enable = true;
    settings.General.EnableNetworkConfiguration = true;
    # iwd's default is systemd-resolved, which isn't running here; NixOS
    # manages /etc/resolv.conf with resolvconf (openresolv).
    settings.Network.NameResolvingService = "resolvconf";
  };
  environment.persistence."/persist".directories = [
    "/var/lib/iwd" # Known networks + passphrases.
  ];

  # Laptop: battery state for the bar and power tools.
  services.upower.enable = true;

  home-manager.users.andrew.imports = [ ./home.nix ];
}
