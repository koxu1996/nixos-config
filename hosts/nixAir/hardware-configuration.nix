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

  # Manage NixOS config directly from the user directory.
  fileSystems."/etc/nixos" = {
    device = "/home/andrew/nixos";
    fsType = "none";
    options = [ "bind" ];
  };

  swapDevices = [ ];
}
