# nuc: erase and install

Everything except steps 1 and the last reboot runs from nixAir over SSH. `$IP` is the
installer's LAN address.

1. **Boot the installer.** Minimal x86_64 ISO from
   https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso, written
   to a USB stick. On nuc: F10 boot menu, pick the stick, then let my key in (GitHub
   serves ~/.ssh/id_ed25519.pub) and note the address:
   ```
   mkdir -p ~/.ssh && curl -L https://github.com/koxu1996.keys > ~/.ssh/authorized_keys
   ip -br a
   ```

2. **Erase the disk fully**, with the drive's own sanitize/secure erase (an SSD keeps
   spare blocks that overwriting never reaches):
   ```
   ssh nixos@$IP lsblk -d -o NAME,SIZE,MODEL,TRAN,ROTA
   # NVMe:
   ssh nixos@$IP sudo nix run nixpkgs#nvme-cli -- sanitize /dev/nvme0 --sanact=2   # block erase
   ssh nixos@$IP sudo nix run nixpkgs#nvme-cli -- sanitize-log /dev/nvme0          # until done
   #   (no sanitize support: nvme format /dev/nvme0n1 --ses=2, crypto erase)
   # SATA SSD: hdparm --security-erase-enhanced (drive must not be "frozen").
   # Check: sudo hexdump -C /dev/nvme0n1 | head   → one line of zeros (or ff), then '*'
   ```

3. **Scan the hardware** and point disko at the disk:
   ```
   ssh nixos@$IP sudo nix run nixpkgs#nixos-facter -- -o /tmp/facter.json
   scp nixos@$IP:/tmp/facter.json hosts/nuc/facter.json && git add hosts/nuc/facter.json
   ssh nixos@$IP ls -l /dev/disk/by-id   # → disk.main.device in disko.nix
   ```

4. **Seed /persist** with an SSH host key and machine-id, so the host key is known
   before the first boot (known_hosts, a sops recipient later):
   ```
   seed=$(mktemp -d); install -d -m 755 $seed/persist/etc/ssh
   ssh-keygen -t ed25519 -N "" -C root@nuc -f $seed/persist/etc/ssh/ssh_host_ed25519_key
   systemd-id128 new > $seed/persist/etc/machine-id
   ```

5. **Install** (builds on nuc itself: nixAir is aarch64):
   ```
   nix run github:nix-community/nixos-anywhere -- --flake .#nuc \
     --build-on remote --extra-files $seed --target-host nixos@$IP
   ```
   It partitions and formats with disko (wiping the disk), installs and reboots. Pull the
   USB stick. Then `ssh andrew@$IP` (LAN), `sudo tailscale up`, and from then on `ssh nuc`.
   Delete `$seed` (its key is now on nuc).

Later changes: `nixos-rebuild switch --flake .#nuc --target-host nuc --use-remote-sudo
--build-host nuc`.
