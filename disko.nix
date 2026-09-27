# disko.nix — declarative description of this machine's disk layout.
#
# IMPORTANT: `disko.enableConfig = false` below. This machine was installed by
# hand (see the erase-your-darlings ZFS setup), so disko here does NOT generate
# any `fileSystems`/`boot`/`swap` config — those stay owned by
# hardware-configuration.nix (the OS mounts) and monero.nix (the /xmr mount).
# disko is used purely as:
#   1. a single, declarative record of the partition + ZFS layout, and
#   2. a tested recovery / reinstall recipe.
#
# It is therefore SAFE to `nixos-rebuild switch` with this module: it changes
# nothing about how the running system mounts. Formatting only ever happens if
# you EXPLICITLY run the disko script against a disk, e.g. on a fresh install:
#
#   sudo nix run github:nix-community/disko -- \
#     --mode destroy,format,mount --flake /etc/nixos#nixPC
#
# CAUTION: that command is destructive. Never run it against the live pool.
# (On a fresh install disko writes its own GPT labels "disk-main-ESP" /
# "disk-main-nix"; the hand-made disk uses "ESP" / "nix" - harmless while
# enableConfig=false since disko emits no fileSystems here.)
#
# Layout captured from the running system (2026): single 4 TB USB NVMe
# (OWC Express 1M2), GPT, 1 GiB ESP + rest ZFS (rpool, ashift=12).
{ ... }:

{
  # Do not emit fileSystems/boot/swap config — see header. Layout only.
  disko.enableConfig = false;

  disko.devices = {
    disk.main = {
      type = "disk";
      # Stable by-id path for the OWC Express 1M2 enclosure (was /dev/sdb).
      device = "/dev/disk/by-id/usb-OWC_Express_1M2_2410264819E5-0:0";
      content = {
        type = "gpt";
        partitions = {
          # 1 GiB EFI System partition, mounted at /boot. GPT name "ESP"
          # matches the existing partition label.
          ESP = {
            priority = 1;
            name = "ESP";
            start = "2M"; # 2 MiB offset for optimal alignment (matches install).
            size = "1024M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "fmask=0022" "dmask=0022" ];
            };
          };
          # Remainder of the disk is the ZFS pool member. GPT name "nix"
          # matches the existing partition label.
          nix = {
            name = "nix";
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
      mode = ""; # single disk, no redundancy (stripe).
      options.ashift = "12";

      # Pool-level properties, inherited by every dataset. acltype=posixacl +
      # xattr=sa are required for e.g. `journalctl --user` to work.
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
          # Recreate the blank snapshot the rollback service depends on.
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
            redundant_metadata = "none";
          };
        };

        # Persisted state (survives the root rollback). neededForBoot is set on
        # the mount in hardware-configuration.nix / impermanence, not here.
        "safe/persist" = {
          type = "zfs_fs";
          mountpoint = "/persist";
          options.mountpoint = "legacy";
        };

        # Monero blockchain. The runtime /xmr mount is owned by monero.nix;
        # disko only provisions the dataset (with its tuned properties).
        "safe/xmr" = {
          type = "zfs_fs";
          mountpoint = "/xmr";
          options = {
            mountpoint = "legacy";
            atime = "off";
            sync = "disabled";
          };
        };
      };
    };
  };
}
