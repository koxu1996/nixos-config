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
      # previous boots.
      #"/etc/machine-id"
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
      ] ++ lib.optionals (config.services.tpm2-passkey.enable or false) [
        # Passkey store (TPM-wrapped keys + TPM-sealed AES key) - without it
        # every reboot wipes all passkeys.
        { directory = ".local/share/tpm2-passkey"; mode = "0700"; }
      ] ++ lib.optionals config.programs.steam.enable [
        ".local/share/Steam" # Steam library + installed games (CS2 ~35 GB).
        ".steam" # Steam runtime, login session, compat tools.
      ] ++ [
        # Claude Code: login token (.credentials.json), session transcripts
        # (projects/), settings, todos. mode 0700 to protect the OAuth token.
        { directory = ".claude"; mode = "0700"; }
        { directory = ".config/clutch"; mode = "0700"; } # clutch HUD config + OpenCode Zen API key.
        # Quickshell bar state: Glow mode/manual values, notifications + do-not-disturb.
        ".local/state/quickshell"
        # Agent usage panel (home/agent-usage): the subscription-account registry and the
        # added accounts' homes (their own OAuth credentials, hence 0700), usage records,
        # panel order.
        { directory = ".local/state/omarchy"; mode = "0700"; }
        # OpenCode's database: its sessions, and the per-response costs the Zen balance
        # estimate subtracts.
        ".local/share/opencode"
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
