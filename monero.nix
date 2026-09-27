# monero.nix — full Monero node (monerod) run as a system daemon.
#
# The blockchain lives on its own ZFS dataset (rpool/safe/xmr, ~261 GiB). That
# is a "safe" dataset, so it survives the impermanence root rollback. This
# module owns BOTH the storage mount and the daemon, so the dataset/mountpoint
# below is the single storage input you supply.
#
# The monero-gui wallet (installed in home.nix) is expected to connect to this
# local node as a "remote node" at 127.0.0.1:18081, rather than running its own
# bundled node.
#
# ONE-TIME MIGRATION when first enabling: the existing blockchain was synced as
# the `andrew` user, but monerod runs as the system `monero` user. Hand the data
# directory over once (monerod's first start will fail until you do this):
#
#     sudo chown -R monero:monero /xmr/.bitmonero
#     sudo systemctl restart monero
#
# The `monero` user's uid is allocated into /var/lib/nixos (persisted in
# persist.nix), so ownership stays stable across the stateless root rollback.
{ ... }:

let
  # --- Storage input ---------------------------------------------------------
  dataset = "rpool/safe/xmr"; # ZFS dataset holding the blockchain.
  mountPoint = "/xmr"; # Where that dataset is mounted.
  dataDir = "${mountPoint}/.bitmonero"; # monerod data dir (lmdb/, p2pstate.bin, ...).
in
{
  # Mount the blockchain dataset. Moved here out of hardware-configuration.nix
  # so this module is self-contained (legacy mountpoint, matches the pool).
  fileSystems.${mountPoint} = {
    device = dataset;
    fsType = "zfs";
  };

  services.monero = {
    enable = true;
    inherit dataDir;
    # Full (non-pruned) node. RPC stays on loopback (default 127.0.0.1:18081)
    # for the local monero-gui wallet.
  };

  # Don't let monerod start before its blockchain dataset is mounted, otherwise
  # it would write a fresh chain into an empty mountpoint.
  systemd.services.monero.unitConfig.RequiresMountsFor = mountPoint;
}
