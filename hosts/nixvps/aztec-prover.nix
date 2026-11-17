# The Aztec prover stack (aztec-nahui, ~/aztec-nahui on nixvps) as systemd services, so the
# live run survives crashes and reboots. Every piece of state stays where the hand-started
# run kept it (~/aztec-nahui/.aztec-prover), so nothing resyncs. Secrets come from
# ~/.config/aztec-prover/secrets.env (mode 600, KEY=value; never in the store):
# ETHEREUM_HOSTS, SERVE_WORKER_TOKEN, NTFY_URL. Steps and checks: ~/aztec-nahui/NIXOS.md.
{ aztec-nahui, pkgs, ... }:
let
  state = "/home/andrew/aztec-nahui/.aztec-prover";

  # `nixvps-update [--restart]`, on nixvps: switch to this repository's nixvps config as
  # pushed to GitHub, with aztec-nahui taken from ~/aztec-nahui's committed master (not the
  # working tree, nor the lock here), so prover changes deploy from nixvps without this
  # repository. Evaluates and builds as the caller; only the activation uses sudo (as root,
  # git would refuse a repository owned by andrew). --restart then restarts the units a
  # switch leaves running (aztec-prover-restart waits until that costs no time).
  nixvps-update = pkgs.writeShellApplication {
    name = "nixvps-update";
    text = ''
      restart=0
      for arg in "$@"; do
        case "$arg" in
          --restart) restart=1 ;;
          *) echo "usage: nixvps-update [--restart]" >&2; exit 2 ;;
        esac
      done
      nixos-rebuild switch --sudo --refresh \
        --flake github:koxu1996/nixos-config#nixvps \
        --override-input aztec-nahui "git+file:///home/andrew/aztec-nahui?ref=refs/heads/master"
      if [ "$restart" = 1 ]; then
        sudo aztec-prover-restart node serve submit worker-gateway aztec-l1-reth aztec-l1-lighthouse
      fi
    '';
  };
in
{
  imports = [ aztec-nahui.nixosModules.default aztec-nahui.nixosModules.l1 ];

  services.aztec-l1 = {
    enable = true;
    stateDir = "${state}/l1";
    user = "andrew";
    group = "users";
  };

  services.aztec-prover = {
    enable = true;
    components = [ "serve" "node" "submit" "worker-gateway" "orchestrate" "watchdog" ];
    stateDir = state;
    user = "andrew";
    group = "users";
    environmentFile = "/home/andrew/.config/aztec-prover/secrets.env";
    # No PROVER_NODE_ONLY_EPOCH (.env still has 1257 from the capture runs): with it the
    # node would prove only that epoch.
    settings = {
      L1_CONSENSUS_HOST_URLS = "http://127.0.0.1:5052";
      ARCHIVER_SKIP_HISTORICAL_LOGS_CHECK = "true";
      BROKER_PORT = "18080";
      NODE_PORT = "18081";
      AGENT_PORT = "18082";
      WS_NUM_HISTORIC_CHECKPOINTS = "2000";
      WS_NUM_HISTORIC_BLOCKS = "2000";
      PROVER_NODE_SPECULATE = "1";
      PROVER_PREPARED_DIR = "/state/prepared";
      SERVE_CALIBRATION = "/state/bundles/calibration-ifma.jsonl";
      # Cap local proving so an epoch's bb-avm burst can't starve the node and
      # L1 clients: the box has 16 cores and 62 GiB with no swap. SERVE_CORES
      # defaults to nproc*9/8 (18 here), which overcommits; 12 leaves ~4 cores
      # for node/reth/lighthouse. 40 GiB let ~5 bb-avm (~8 GiB each) run at once
      # and hit memory pressure; 28 caps that to ~3 and keeps headroom. The GCP
      # workers take the overflow.
      SERVE_CORES = "12";
      SERVE_MEMORY_GB = "28";
      SERVE_WORKER_LISTEN = "127.0.0.1:8470";
      WORKER_GATEWAY_IP = "152.53.157.65";
      GCP_PROJECT = "aztec-prover-514814";
      SUBMIT_SEND = "0";
    };
    orchestrate = {
      args = [ "--max-workers" "8" ];
      credentialsFile = "/home/andrew/.config/gcloud/aztec-prover.json";
    };
  };

  environment.systemPackages = [ nixvps-update ];

  # The GCP workers reach the service through this port.
  networking.firewall.allowedTCPPorts = [ 8443 ];
}
