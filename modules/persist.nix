# https://github.com/nix-community/impermanence#module-usage
{ config, lib, ... }:

{
  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/tailscale" # Tailscale node keys/state - survive root rollback.
      "/var/lib/lockdown" # usbmuxd: iOS pairing records, so a trusted iPhone stays trusted.
      "/var/lib/nixos" # See: https://github.com/nbraud/nixpkgs/blob/6b6b12c27cb9e21d6530b8139591c7696b2dca2f/nixos/doc/manual/administration/nixos-state.section.md
      #"/var/lib/systemd/coredump"
      #"/etc/NetworkManager/system-connections"
    ];
    files = [
      # machine-id is used by systemd for the journal, if you don't persist this
      # file you won't be able to easily use journalctl to look at journals for
      # previous boots (every boot got a new id and its own /var/log/journal/<id>).
      # Seed it once per host before switching: sudo install -D -m 444 /etc/machine-id /persist/etc/machine-id
      "/etc/machine-id"
      # See: https://github.com/nbraud/nixpkgs/blob/6b6b12c27cb9e21d6530b8139591c7696b2dca2f/nixos/doc/manual/administration/nixos-state.section.md
      #"/etc/passwd"
      #"/etc/group"
      #"/etc/shadow"
      #"/etc/gshadow"
      #"/etc/subuid"
      #"/etc/subgid"
    ];
    users.andrew = {
      directories = [
        "nixos"
        "projects" # Code to work on (clones, own projects).
        #".local/share/kscreen"
        #".local/share/kwalletd"
        #".local/share/sddm"
        #".local/share/zoxide"
        "Downloads"
        "Sync" # Syncthing-shared folder (KeePassXC database lives here).
        # https://discourse.nixos.org/t/slow-application-startup/29857/3
        ".cache"
        { directory = ".ssh"; mode = "0700"; }
        { directory = ".gnupg"; mode = "0700"; } # GPG keyring - signing key must survive rollback.
        ".config/gh" # GitHub CLI auth token + config.
        ".local/state/zsh" # Persist as directory (not file) to avoid bind mount rename issue.
        ".local/state/syncthing" # Syncthing device key, certs, and DB.
        ".local/share/hyprland" # lastVersion/lastNag - otherwise the update popup reappears after every reboot.
        { directory = ".local/state/pkee"; mode = "0700"; } # pkee: frecency (which entries I use) and the agent log.
      ] ++ lib.optionals (config.services.linux-passkey.enable or false) [
        # Passkey store (hardware-wrapped keys + hardware-sealed store key) -
        # without it every reboot wipes all passkeys.
        { directory = ".local/share/linux-passkey"; mode = "0700"; }
        # Pre-rename store (tpm2-passkey). linux-passkey copied it on first
        # start; kept as a backup. Drop once the new store has proven itself.
        { directory = ".local/share/tpm2-passkey"; mode = "0700"; }
      ] ++ lib.optionals config.programs.steam.enable [
        ".local/share/Steam" # Steam library + installed games (CS2 ~35 GB).
        ".steam" # Steam runtime, login session, compat tools.
      ] ++ [
        # Claude Code: login token (.credentials.json), session transcripts
        # (projects/), settings, todos. mode 0700 to protect the OAuth token.
        { directory = ".claude"; mode = "0700"; }
        { directory = ".config/clutch"; mode = "0700"; } # clutch HUD config + OpenCode Zen API key.
        # silk-wallet: Cloudflare API token (cf-token) for the silk-chunks R2 bucket and
        # chunks.silkmoney.net; R2 upload keys are derived from it.
        { directory = ".config/silk"; mode = "0700"; }
        # xcross (Flutter iOS builds from Linux): Apple ID session, signing
        # certificates and the Darwin SDK (~900 MB, built from an Xcode.app/.xip).
        { directory = ".config/xcross"; mode = "0700"; }
        # Quickshell bar state: Glow mode/manual values, notifications + do-not-disturb.
        ".local/state/quickshell"
        # Agent usage panel (home/agent-usage): the subscription-account registry and the
        # added accounts' homes (their own OAuth credentials, hence 0700), usage records,
        # panel order.
        { directory = ".local/state/omarchy"; mode = "0700"; }
        # OpenCode's database: its sessions, and the per-response costs the Zen balance
        # estimate subtracts.
        ".local/share/opencode"
        # herdr (agent multiplexer): config.toml, session layouts, its server socket and logs.
        { directory = ".config/herdr"; mode = "0700"; }
        # herdr's saved SSH machines (client/endpoints.json) and agent detection state.
        { directory = ".local/state/herdr"; mode = "0700"; }
      ];
      files = [
        ".claude.json" # Claude Code: account info + per-project prompt history.
        #".bash_history"
        #".config/systemsettingsrc"
        #".zsh_history" # Moved to .local/state/zsh directory - see above.
        #".config/tbsm/000-default-session.desktop"
        #".config/tbsm/001-last-session.desktop"
      ];
    };
  };
}
