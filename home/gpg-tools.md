# gpg-tools — KeePass-backed, RAM-only GPG keys

Use GPG keys that live (encrypted) inside the KeePass database, loaded into a **RAM-only**
keyring on demand and auto-wiped after 15 min. The key never touches persistent
disk. Commands are defined in `gpg-tools.nix`: `gpg-load` and `tgpg`.

## a) Put a key into KeePass (strip its passphrase first)

Keys stored in KeePass must be **armored** text and **passphrase-less** — KeePass
is itself the encrypted container. Convert once, entirely in RAM:

```bash
work=$(mktemp -d -p /run/user/1000); chmod 700 "$work"; export GNUPGHOME="$work"

gpg --pinentry-mode loopback --import ~/path/to/privkey   # .asc OR binary, auto-detected
gpg --list-secret-keys                                    # note the KEYID
gpg --pinentry-mode loopback --passwd <KEYID>             # enter CURRENT passphrase; NEW = empty (just press Enter)
gpg --armor --export-secret-keys <KEYID>                  # prints the naked armored key ↓

gpgconf --kill gpg-agent 2>/dev/null; unset GNUPGHOME; rm -rf "$work"
```

Copy the printed `-----BEGIN PGP PRIVATE KEY BLOCK----- … END` block into a
KeePass entry's **Notes** field (KeePassDX on the phone, or any KeePass app
opened with the key file).

## b) Load a key (paste from KeePass)

```bash
gpg-load            # or: gpg-load 30   (minutes until auto-wipe, default 15)
```

Open the entry in pkee (Enter shows its notes), select the key and copy it, paste it at the prompt,
then press **Ctrl-D**. It is imported into the RAM keyring and auto-wipes after
the timeout (re-run to reset the clock; logout/reboot also wipes it).

Check remaining time:

```bash
systemctl --user list-timers gpg-session-expire.timer
```

## c) Use it (decrypt / encrypt)

`tgpg` is plain `gpg` pinned to the RAM keyring:

```bash
tgpg -d secret.gpg                 # decrypt to stdout
tgpg -o out.txt -d secret.gpg      # decrypt to a file
tgpg -e -r <KEYID> file            # encrypt to yourself
tgpg -c file                       # symmetric (no key)
tgpg --list-secret-keys            # show what's currently loaded
```

Plain `gpg` won't see the key — it uses the default `~/.gnupg`. `tgpg` points at
the tmpfs keyring where `gpg-load` put it (which is also why the key stays off
persistent disk).
