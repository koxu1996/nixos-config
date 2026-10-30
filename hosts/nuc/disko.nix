# nuc's disk: GPT, 1 GiB ESP + the rest as ZFS (rpool), with the same datasets as the
# other hosts (local/root rolled back to @blank on boot, safe/persist kept). Unlike
# nixPC, disko owns the mounts here (enableConfig stays on): nuc is installed with it.
#
# Destructive only when run explicitly (nixos-anywhere, or disko --mode destroy,format,mount).
{ ... }:

{
  disko.devices = {
    disk.main = {
      type = "disk";
      # Samsung 980 PRO 2TB (NVMe).
      device = "/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_2TB_S69ENX0TB08531R";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            priority = 1;
            size = "1024M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "fmask=0077" "dmask=0077" ];
            };
          };
          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "rpool";
            };
          };
        };
      };
    };

    zpool.rpool = {
      type = "zpool";
      mode = ""; # Single disk.
      options.ashift = "12";
      # acltype=posixacl + xattr=sa: needed for e.g. `journalctl --user`.
      rootFsOptions = {
        compression = "lz4";
        atime = "off";
        acltype = "posixacl";
        xattr = "sa";
        mountpoint = "none";
      };

      datasets = {
        local = {
          type = "zfs_fs";
          options = { mountpoint = "none"; canmount = "off"; };
        };
        safe = {
          type = "zfs_fs";
          options = { mountpoint = "none"; canmount = "off"; };
        };

        # Stateless root, rolled back to @blank on every boot (modules/zfs-impermanence.nix).
        "local/root" = {
          type = "zfs_fs";
          mountpoint = "/";
          options.mountpoint = "legacy";
          postCreateHook = "zfs snapshot rpool/local/root@blank";
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
          };
        };
        # Everything that survives a reboot (see environment.persistence in default.nix).
        "safe/persist" = {
          type = "zfs_fs";
          mountpoint = "/persist";
          options.mountpoint = "legacy";
        };
      };
    };
  };
}
