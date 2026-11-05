# nixAir — MacBook Air M2 13" (2022), aarch64, NixOS next to macOS and Arch on
# the internal disk. ZFS pool `mpool` on one partition (see disko.nix).
{ config, lib, pkgs, ... }:

let
  zfsModule = config.boot.kernelPackages.${config.boot.zfs.package.kernelModuleAttribute};
in
{
  imports = [
    ./hardware-configuration.nix
    ./touchid.nix
  ];

  # Touch ID through the Secure Enclave (see HANDOVER-touchid.md). The read-only
  # boots passed (2026-10-21: endpoints to 0x12, sensor bound in mode 1, calibration
  # sha256 matches macOS, xART 12 live records, applesep trusted-key source); the
  # iBoot container is backed up (isc-j413-backup.img). Writes on: keybag provisioning.
  my.touchid.enable = true;

  # Passkeys (FIDO2) with keys in the Secure Enclave: a dialog naming the site
  # and account, then the fingerprint. Needs the key-ioctls patch (/dev/sep-key,
  # hosts/nixAir/touchid). Store persisted in modules/persist.nix.
  services.linux-passkey = {
    enable = true;
    user = "andrew";
    backend = "sep";
    uv = "fprintd";
  };
  my.touchid.xartWrites = true;

  hardware.asahi.enable = true;

  # The regulatory database (regulatory.db), so cfg80211.ieee80211_regdom=PL below
  # actually loads: without it the kernel stays in the world domain "00" and brcmfmac
  # never hands the firmware a country (it keeps its worldwide "XZ" code; the DT patch
  # 0001-j413-wifi-ccode-map-trivial lets PL through). Not what hung joins, though:
  # that was feature_disable, see boot.kernelParams.
  hardware.wirelessRegulatoryDatabase = true;

  # Apple's peripheral firmware (Wi-Fi, webcam, ...) from the ESP the Asahi
  # installer filled. It is non-redistributable and never committed, so nixAir
  # is always built with `--impure`. /mnt/boot/vendorfw: building from the installer.
  hardware.asahi.peripheralFirmwareDirectory = lib.findFirst
    (dir: builtins.pathExists (dir + "/firmware.cpio"))
    (throw "nixAir: no vendorfw/firmware.cpio found - build with --impure on the Mac")
    [ /boot/vendorfw /mnt/boot/vendorfw ];

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
  # my.look.notchGap).
  # No brcmfmac.feature_disable=0x82000 (the Intel-Mac Wi-Fi quirk): on this BCM4387 it
  # stops association outright (iwd hangs in "connecting") and after a try or two the
  # firmware stops answering until brcmfmac is reloaded (omarchy#7439; seen here 2026-10-25).
  boot.kernelParams = [
    "appledrm.show_notch=1"
    # Touch ID: pin the OS identity the enclave was provisioned with (2026-10-21), so a
    # bootloader change cannot orphan enrolled fingerprints. m1n1's apfs-preboot-uuid
    # 38E4E9B9-98B5-49F5-B7DD-471A4BDFCAAC as two big-endian u64 halves (decimal).
    "apple_sep.os_uuid_hi=4099658544154233333" # 0x38E4E9B998B549F5
    "apple_sep.os_uuid_lo=13248823857061546668" # 0xB7DD471A4BDFCAAC
    "cfg80211.ieee80211_regdom=PL"
  ];

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

  # The power button is also the Touch ID key: a press meant for the fingerprint must not
  # power off. Holding it still forces the hardware off. Shutdown goes through the bar menu.
  services.logind.settings.Login = {
    HandlePowerKey = "ignore";
    HandlePowerKeyLongPress = "ignore";
  };

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
    # IPv6 is left to the kernel: iwd follows the RA "managed" flag over a usable
    # SLAAC prefix and has no privacy addresses. DNS stays on IPv4 (DHCP).
    settings.Network.EnableIPv6 = false;
  };
  # Kernel SLAAC on wlan0, with a stable address from a random secret instead of
  # the MAC (temporary addresses are on by default via networking.tempAddresses).
  boot.kernel.sysctl = {
    "net.ipv6.conf.wlan0.accept_ra" = 1;
    "net.ipv6.conf.wlan0.addr_gen_mode" = 3;
  };
  environment.persistence."/persist".directories = [
    "/var/lib/iwd" # Known networks + passphrases.
  ];

  # Laptop: battery state for the bar and power tools.
  services.upower.enable = true;

  # Flutter apps (LocalSend) draw their icons but no text: Flutter's linux-arm64 engine is
  # built without fontconfig and only scans /usr/share/fonts, which NixOS lacks. Give it
  # the system fonts there. Drop with Flutter 3.50 (flutter/flutter#180235; NixOS/nixpkgs#573374).
  fonts.fontDir.enable = true;
  systemd.tmpfiles.rules = [
    "d /usr/share 0755 root root -"
    "L+ /usr/share/fonts - - - - /run/current-system/sw/share/X11/fonts"
  ];

  home-manager.users.andrew.imports = [ ./home.nix ];
}
