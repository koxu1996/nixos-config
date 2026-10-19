# gpg-tools — use a GPG key in a RAM-only keyring, without ever writing it to
# persistent disk.
#
# Provides two commands:
#   gpg-load [minutes]
#       Prompt to paste an armored, passphrase-LESS GPG private key, import it
#       into a RAM-only (tmpfs) GnuPG home under $XDG_RUNTIME_DIR, and arm a
#       one-shot systemd timer that wipes it after N minutes (default 15).
#       Re-running resets the clock; logout/reboot wipes it too. You paste the
#       key by hand (e.g. copied out of KeePassXC) — nothing plaintext ever
#       touches persistent disk.
#   tgpg <args...>
#       Plain `gpg` pinned to that RAM keyring, e.g.
#         tgpg -d secret.gpg   tgpg -e -r me file   tgpg -c file
{ pkgs, ... }:

let
  gpg-load = pkgs.writeShellApplication {
    name = "gpg-load";
    runtimeInputs = [ pkgs.gnupg pkgs.systemd pkgs.coreutils ];
    text = ''
      if [[ "''${1:-}" == "-h" || "''${1:-}" == "--help" ]]; then
        printf '%s\n' \
          "gpg-load — paste a GPG private key into a RAM-only keyring" \
          "" \
          "Usage: gpg-load [minutes]   (auto-wipe after N minutes, default 15)" \
          "" \
          "Paste an armored, passphrase-less private key when prompted (end with Ctrl-D)." \
          "Then use it with:  tgpg -d file.gpg  /  tgpg -e -r me file"
        exit 0
      fi
      ttl="''${1:-15}"

      export GNUPGHOME="''${XDG_RUNTIME_DIR:?}/gnupg-session"
      mkdir -p "$GNUPGHOME"
      chmod 700 "$GNUPGHOME"

      tmp="$(mktemp -p "''${XDG_RUNTIME_DIR}" key.XXXXXX.asc)"
      trap 'shred -u "$tmp" 2>/dev/null || rm -f "$tmp"' EXIT

      echo "Paste the armored GPG private key (no passphrase), then press Ctrl-D:" >&2
      cat > "$tmp"

      gpg --batch --import "$tmp"

      # (Re)arm the expiry: kill the agent (clears RAM) + rm the tmpfs keyring.
      systemctl --user stop gpg-session-expire.timer gpg-session-expire.service 2>/dev/null || true
      systemctl --user reset-failed gpg-session-expire.service 2>/dev/null || true
      systemd-run --user --quiet --unit=gpg-session-expire --on-active="''${ttl}min" \
        sh -c "GNUPGHOME='$GNUPGHOME' gpgconf --kill gpg-agent 2>/dev/null; rm -rf '$GNUPGHOME'"

      echo "Loaded into RAM keyring; auto-wipes in ''${ttl} min. Use: tgpg -d file.gpg" >&2
    '';
  };

  tgpg = pkgs.writeShellApplication {
    name = "tgpg";
    runtimeInputs = [ pkgs.gnupg ];
    text = ''
      exec env GNUPGHOME="''${XDG_RUNTIME_DIR:?}/gnupg-session" gpg "$@"
    '';
  };
in
{
  home.packages = [ gpg-load tgpg ];
}
