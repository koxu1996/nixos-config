# nixAir — MacBook Air M2 13" (2022, j413ap). Kernel, initrd and boot chain
# (m1n1 → U-Boot → systemd-boot) come from nixos-apple-silicon.
{ ... }:

let
  ids = import ./disk-ids.nix;
in
{
  fileSystems."/" = {
    device = "mpool/local/root";
    fsType = "zfs";
  };

  # The ESP the Asahi installer created for this OS (holds m1n1/U-Boot and the
  # vendor firmware). Mounted only, never formatted.
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/${ids.espUuid}";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  fileSystems."/nix" = {
    device = "mpool/local/nix";
    fsType = "zfs";
  };

  fileSystems."/tmp" = {
    device = "mpool/local/tmp";
    fsType = "zfs";
  };

  fileSystems."/persist" = {
    device = "mpool/safe/persist";
    fsType = "zfs";
    neededForBoot = true;
  };

  # Copy of the old Arch install's backup SSD (home + system notes), to clean up
  # over time. Its own dataset: `zfs list` shows its size, `zfs destroy` drops it.
  # Created by hand (`zfs create -o mountpoint=legacy mpool/safe/arch-backup`), not by disko.
  fileSystems."/persist/arch-backup" = {
    device = "mpool/safe/arch-backup";
    fsType = "zfs";
    options = [ "nofail" ]; # boot on without it (e.g. once destroyed)
  };

  # Manage NixOS config directly from the user directory.
  fileSystems."/etc/nixos" = {
    device = "/home/andrew/nixos";
    fsType = "none";
    options = [ "bind" ];
  };

  swapDevices = [ ];
}
