# https://github.com/nix-community/impermanence#module-usage
{
  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/tailscale" # Tailscale node keys/state - survive root rollback.
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
        #".local/share/kscreen"
        #".local/share/kwalletd"
        #".local/share/sddm"
        #".local/share/zoxide"
        "Downloads"
        # https://discourse.nixos.org/t/slow-application-startup/29857/3
        ".cache"
        { directory = ".ssh"; mode = "0700"; }
        { directory = ".gnupg"; mode = "0700"; } # GPG keyring - signing key must survive rollback.
        ".local/state/zsh" # Persist as directory (not file) to avoid bind mount rename issue.
      ];
      files = [
        #".bash_history"
        #".config/systemsettingsrc"
        #".zsh_history" # Moved to .local/state/zsh directory - see above.
        #".config/tbsm/000-default-session.desktop"
        #".config/tbsm/001-last-session.desktop"
      ];
    };
  };
}
