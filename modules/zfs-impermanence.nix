# zfs-impermanence.nix — ZFS root that is rolled back to a blank snapshot on
# every boot. The pool layout itself is described per host (hosts/*/disko.nix);
# every host's pool has the same datasets, only the pool name differs.
{ config, lib, ... }:

let
  pool = config.my.zfs.pool;
in
{
  options.my.zfs.pool = lib.mkOption {
    type = lib.types.str;
    example = "rpool";
    description = "Name of the ZFS pool holding local/root, local/nix, local/tmp and safe/persist.";
  };

  config = {
    # Keep force-importing the ZFS root (current behavior) and silence the 26.11
    # default-change warning. Safe on a single-machine local pool; set to false
    # only if this pool could ever be imported by another running system.
    boot.zfs.forceImportRoot = true;

    # Rollback root dataset on boot.
    boot.initrd.systemd.services.rollback-root = {
      description = "Rollback ZFS root dataset to blank snapshot";
      wantedBy = [ "initrd.target" ];
      after = [ "zfs-import-${pool}.service" ];
      before = [ "sysroot.mount" ];
      path = [ config.boot.zfs.package ];
      unitConfig.DefaultDependencies = "no";
      serviceConfig.Type = "oneshot";
      script = ''
        zfs rollback -r ${pool}/local/root@blank
      '';
    };
  };
}
