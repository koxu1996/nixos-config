# disko.nix — nixAir's ZFS pool. The Mac's disk is shared with macOS and Apple's
# boot/recovery partitions, so disko only ever sees ONE
# partition (by PARTUUID) and puts the pool directly on it: no partition table
# is written, and the ESP is mounted, never formatted (hardware-configuration.nix).
#
# As on nixPC, `disko.enableConfig = false`: mounts are owned by
# hardware-configuration.nix; disko is the format recipe used once from the
# installer, with `--mode format,mount` (never `destroy`).
{ ... }:

let
  ids = import ./disk-ids.nix;
in
{
  disko.enableConfig = false;

  disko.devices = {
    disk.nix = {
      type = "disk";
      device = "/dev/disk/by-partuuid/${ids.zfsPartUuid}";
      # Never wipe in the destroy stage, even if someone runs it.
      destroy = false;
      content = {
        type = "zfs";
        pool = "mpool";
      };
    };

    zpool.mpool = {
      type = "zpool";
      mode = ""; # single partition, no redundancy.
      options.ashift = "12";

      # Same pool-level properties as nixPC's rpool.
      rootFsOptions = {
        compression = "lz4";
        atime = "off";
        acltype = "posixacl";
        xattr = "sa";
        mountpoint = "none";
      };

      datasets = {
        # Container datasets - never mounted themselves.
        local = {
          type = "zfs_fs";
          options = {
            mountpoint = "none";
            canmount = "off";
          };
        };
        safe = {
          type = "zfs_fs";
          options = {
            mountpoint = "none";
            canmount = "off";
          };
        };

        # Stateless root - rolled back to @blank on every boot (impermanence).
        "local/root" = {
          type = "zfs_fs";
          mountpoint = "/";
          options.mountpoint = "legacy";
          postCreateHook = "zfs snapshot mpool/local/root@blank";
        };
        "local/nix" = {
          type = "zfs_fs";
          mountpoint = "/nix";
          options.mountpoint = "legacy";
        };
        "local/tmp" = {
          type = "zfs_fs";
          mountpoint = "/tmp";
          options = {
            mountpoint = "legacy";
            quota = "16G";
            sync = "disabled";
            redundant_metadata = "none";
          };
        };

        # Persisted state (survives the root rollback).
        "safe/persist" = {
          type = "zfs_fs";
          mountpoint = "/persist";
          options.mountpoint = "legacy";
        };
      };
    };
  };
}
