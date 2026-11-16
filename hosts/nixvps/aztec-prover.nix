# The Aztec prover stack (aztec-nahui, ~/aztec-nahui on nixvps) as systemd services, so the
# live run survives crashes and reboots. Every piece of state stays where the hand-started
# run kept it (~/aztec-nahui/.aztec-prover), so nothing resyncs. Secrets come from
# ~/.config/aztec-prover/secrets.env (mode 600, KEY=value; never in the store):
# ETHEREUM_HOSTS, SERVE_WORKER_TOKEN, NTFY_URL. Steps and checks: ~/aztec-nahui/NIXOS.md.
{ aztec-nahui, ... }:
let
  state = "/home/andrew/aztec-nahui/.aztec-prover";
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
      SERVE_MEMORY_GB = "40";
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

  # The GCP workers reach the service through this port.
  networking.firewall.allowedTCPPorts = [ 8443 ];
}
