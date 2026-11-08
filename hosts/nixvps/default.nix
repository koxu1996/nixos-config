# nixvps — x86_64 VPS (KVM, ext4, public IPv4 + IPv6). Runs a single-node RKE2
# (Kubernetes) cluster and cocoon. On unstable nixpkgs like the other hosts; RKE2 is
# pinned to a minor version below, so Kubernetes only moves on a deliberate bump.
#
# Ported from its hand-kept /etc/nixos/configuration.nix (2026-11). Not on Tailscale,
# so not modules/ssh.nix (Tailscale-only): its own SSH below, open to the internet.
# Secrets stay on the box, outside this repo: /etc/nix/netrc (attic token),
# /etc/cocoon/{env,auth_token}, RKE2's state.
#
# Deploy from a laptop (builds on nixvps itself):
#   nixos-rebuild switch --flake .#nixvps --target-host nixvps --build-host nixvps --sudo
{ pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixvps";
  networking.hosts = { "127.0.0.1" = [ "attic.bron.ski" ]; };

  networking.networkmanager.enable = true;

  # IPv6 setup.
  networking.useDHCP = false;
  networking.interfaces.ens3 = {
    useDHCP = true;
    ipv6.addresses = [{
      address = "2a0a:4cc0:c2:7170::1";
      prefixLength = 64;
    }];
  };
  networking.defaultGateway6 = { address = "fe80::1"; interface = "ens3"; };
  networking.nameservers = [ "2606:4700:4700::1111" "1.1.1.1" ];

  time.timeZone = "Europe/Warsaw";

  # Users stay mutable here: the cocoon service user was created by hand.
  users.users.andrew = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = [
      pkgs.tree
      pkgs.herdr # Agent multiplexer; nixAir/nixPC reach it over SSH (herdr machine add nixvps).
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOBNgSP/ZOH+K/xITHoFBxXcf2ykz60GEztt/YXsP6tH andrzej1_1@o2.pl"
    ];
  };
  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    git
    vim
    btop
    time
    nodejs_24
    kubectl
    kubernetes-helm
    k9s
  ];

  programs.nix-ld.enable = true;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    settings.PermitRootLogin = "no";
  };

  networking.firewall.enable = true;

  system.stateVersion = "26.05";

  # --- RKE2 single-node cluster ---
  services.rke2 = {
    enable = true;
    # Kubernetes minor pinned: upgrade one minor at a time (rke2_1_35 next), never by a
    # nixpkgs update skipping one.
    package = pkgs.rke2_1_34;
    role = "server"; # One server, embedded etcd.
    extraFlags = [
      "--write-kubeconfig-mode=0644" # Readable kubeconfig without sudo.
      "--tls-san=152.53.157.65" # API cert valid for the public IP.
    ];
  };

  # Let in-cluster traffic (pods reaching the API/CoreDNS) flow without opening
  # anything to the internet. Admin access goes over SSH.
  networking.firewall = {
    trustedInterfaces = [ "flannel.1" "cali+" ];
    allowedTCPPorts = [ 6443 ];
  };

  # Give etcd/rke2 I/O + CPU priority so heavy host builds (autoresearch loop) do not starve
  # etcd fsync/heartbeats, which was wedging the control plane. Matches runtime set-property.
  systemd.services.rke2-server.serviceConfig = {
    IOWeight = 1000;
    CPUWeight = 1000;
  };

  # Auto-recovery watchdog: if rke2-server is stuck not-active for >4 min (crash-loop or hung
  # start), run the clean recovery (stop + killall + reset-failed + start) so a transient etcd
  # blip self-heals in minutes instead of looping all night (as happened 2026-10-22/23). A normal
  # ~110s start never trips it. Belt to the autoresearch.slice's hard io.max/cpu.max suspenders.
  systemd.services.rke2-watchdog = {
    description = "Recover rke2-server when it is stuck not-active";
    serviceConfig.Type = "oneshot";
    serviceConfig.ExecStart = pkgs.writeShellScript "rke2-watchdog" ''
      set -u
      SB=/run/current-system/sw/bin
      stamp=/run/rke2-watchdog.notready-since
      state=$($SB/systemctl is-active rke2-server 2>/dev/null || true)
      if [ "$state" = "active" ]; then rm -f "$stamp"; exit 0; fi
      now=$(date +%s)
      if [ ! -f "$stamp" ]; then echo "$now" > "$stamp"; echo "rke2 not active (state=$state); arming"; exit 0; fi
      since=$(cat "$stamp" 2>/dev/null || echo "$now")
      if [ $((now - since)) -lt 240 ]; then exit 0; fi
      echo "rke2 stuck not-active >4min (state=$state); recovering"
      $SB/systemctl stop rke2-server || true
      $SB/rke2-killall.sh || true
      $SB/systemctl reset-failed rke2-server || true
      $SB/systemctl start rke2-server --no-block || true
      rm -f "$stamp"
    '';
  };
  systemd.timers.rke2-watchdog = {
    description = "Run the rke2 watchdog every 2 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = { OnBootSec = "3min"; OnUnitActiveSec = "2min"; };
  };

  environment.variables.KUBECONFIG = "/etc/rancher/rke2/rke2.yaml";

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    extra-substituters = [ "https://attic.bron.ski/cocoon" ];
    extra-trusted-public-keys = [ "cocoon:DIgeTQQnKtx4YMTW5T5EbhWvDzuNQTzD/D/h/UjGOnU=" ];
    netrc-file = "/etc/nix/netrc";
  };

  # --- Cocoon (supervised parallel coding agents) ---
  # The binary is installed by hand in /opt/cocoon, not packaged.
  systemd.services.cocoon = {
    description = "Cocoon - supervised parallel coding agents";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ "/run/current-system/sw" ];
    environment = {
      SHELL = "/bin/sh";
      HOSTNAME = "nixvps";
    };
    serviceConfig = {
      Type = "simple";
      User = "cocoon";
      WorkingDirectory = "/var/lib/cocoon";
      EnvironmentFile = "/etc/cocoon/env";
      ExecStart = "/opt/cocoon/bin/cocoon serve -c /etc/cocoon/cocoon.toml";
      Restart = "on-failure";
      RestartSec = 5;
      KillMode = "mixed";
      TimeoutStopSec = 120;
      StandardOutput = "append:/var/lib/cocoon/cocoon.log";
      StandardError = "append:/var/lib/cocoon/cocoon.log";
    };
  };
}
