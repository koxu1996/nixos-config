# nixAir: second host in nixos-config — design

Date: 2026-10-17
Repo: `gitlab.com/andrzej1_1/nixos-config` (public), working copy `~/nixos` on the Mac (currently Arch Linux ARM / Asahi).

## Intent

One repo is the single source of truth for both of Andrew's machines:

- `nixPC` — the existing x86_64 workstation (ZFS + impermanence, Hyprland + hy3 + waybar, tbsm).
- `nixAir` — new: MacBook Air M2 13" (2022, Apple `j413ap`, aarch64), via nixos-apple-silicon.

nixAir should be the workstation config, adjusted only where the hardware or role differs. The custom look built on the Mac's current Arch install (Quickshell bar, lime palette, drop-down terminal — in `~/.config/home-manager`) is **not** part of this work; it will be migrated into this repo later, for both hosts.

## Goals

1. Restructure the flake into two `nixosConfigurations` (`nixPC`, `nixAir`) sharing all common modules; no copy-pasted duplicates of shared config.
2. `nixAir` builds (aarch64-linux) and installs into the free space on the Mac's internal disk, alongside macOS and the existing Arch install.
3. `nixPC` keeps its behaviour, with these deliberate changes:
   - kernel: from the pinned `linuxPackages_6_12` to **the newest kernel ZFS supports** (computed, not hard-coded, so it never jumps ahead of ZFS);
   - `flake.lock` updated to current nixos-unstable (needed for nixAir; both hosts share one lock).
4. Both hosts build from this checkout before anything is installed or switched.

## Non-goals

- Migrating the Quickshell bar / lime theme / terminal theme (later, separate project).
- Steam/gaming on the Mac.
- Removing the Arch install or reclaiming its partition (later, after NixOS is proven).
- Disk encryption (explicitly declined for nixAir; nixPC unchanged).

## Anti-goals (failure even if it "works")

- **Any write outside the new NixOS partitions on the Mac's disk.** disko must never target `/dev/nvme0n1` as a whole disk (`type = "gpt"` on it wipes macOS/iBoot/recovery and needs a DFU restore). Existing partitions `nvme0n1p1` (iBoot), `p2` (macOS, 180 GB), `p3`+`p4` (Arch's Asahi stub + ESP), `p5` (Arch root), `p6` (recovery) are never modified, formatted or mounted read-write by the install.
- Committing Apple's non-redistributable peripheral firmware to the public repo.
- Committing secrets (passwords, keys, tokens) to the public repo.
- Changing nixPC's disk layout or datasets.

## Decisions made by Andrew

- **Filesystem: ZFS on nixAir**, same model as nixPC (Andrew rejects btrfs). Same impermanence scheme: `local/root` rolled back to `@blank` each boot, `local/nix`, `local/tmp` (16G quota, sync disabled), `safe/persist`. **No `safe/xmr`.**
- **No encryption** on nixAir's pool.
- **No Monero node** on nixAir (`monero.nix` is nixPC-only). monero-gui (the wallet) stays on both.
- **Wi-Fi: iwd, managed with `iwctl`** (terminal, no GUI picker).
- **Steam, gamescope, gamemode: nixPC only.** Also nixPC-only: **tor-browser, bazecor** (not built for aarch64 / not needed).
- **nixPC kernel → newest ZFS-compatible.**
- **Hostname `nixAir`.**
- **Passwords: keep `initialPassword = "pass"` for root and andrew on both hosts** (shared base, unchanged).
- **No data migration in this work:** nixAir boots with an empty home/persist (`.ssh`, `.gnupg`, `Sync`, `.claude`, `gh`, Syncthing identity all fresh). Andrew syncs/copies later. Only the `~/nixos` checkout must be present for rebuilds (cloned on first boot or copied during install).
- **No nixbuild.net.** Nothing in this work may trigger a remote/paid build: nixPC is verified by evaluation only from the Mac (`--dry-run` / `--option builders ""`), and Andrew builds and switches nixPC on the workstation himself.

## Facts established (2026-10-17)

- Kernel.org: stable 7.2.11, 7.3 at rc7; LTS 6.18.57 / 6.12.113.
- nixpkgs unstable: `linuxPackages_latest` 7.2.10, default 6.18.56; ZFS 2.4.4 (`zfs_2_4`), supports kernels ≤ 7.2.
- nixos-apple-silicon (main): kernel `linux-asahi` 7.1.13 → within ZFS's range today. Its installer ISO **disables ZFS** (`boot.supportedFilesystems.zfs = false`).
- Mac page size is 16 KiB.
- Package availability on aarch64 checked: everything in nixPC's `home.packages`/system packages builds except `tor-browser` and `bazecor`; `hy3`, `vscode.fhs`, `okular` are fine.
- Mac disk (`nvme0n1`, 512-byte sysfs sectors): free gap of ~418.6 GB between `p2` and `p3` (sectors 352586544–1170098224).
- Full backup of the Mac's Arch `/home/andrew` and `/etc` exists on an external SSD.

## Architecture

### Repo layout (builder may adjust naming)

```
flake.nix                 two nixosConfigurations; inputs + nixos-apple-silicon
hosts/
  nixPC/   default.nix  hardware-configuration.nix  disko.nix  (+ monero.nix, tpm.nix, steam bits, printer/scanner hw)
  nixAir/  default.nix  hardware-configuration.nix  disko.nix
modules/  (shared NixOS): base (users, nix, locale, zsh, sudo, pki cert, docker, syncthing, tailscale, avahi, pipewire, portal, fonts, issue),
          zfs-impermanence (rollback service parametrised by pool name, persist.nix)
home/     (shared Home Manager): home.nix, hyprland.nix, waybar.nix, gpg-tools.nix, thunderbird.nix, pixma-scan.nix
```

Host-specific Home Manager bits (packages nixPC-only, Hyprland monitor/input differences) go through a small option or a per-host HM module, not `if hostname ==` strings scattered around.

### nixAir specifics

- `nixos-apple-silicon` input, its `apple-silicon-support` module; `boot.loader.systemd-boot.enable = true`, `boot.loader.efi.canTouchEfiVariables = false`.
- Kernel: whatever apple-silicon-support provides (linux-asahi). ZFS module built against it; build must fail loudly (assertion/eval error), never silently drop ZFS, if the kernel exceeds ZFS's max.
- ZFS: pool name **`mpool`** (differs from nixPC's `rpool` so both can be imported on one machine), `ashift=12`, same root properties and datasets as nixPC minus `safe/xmr`. New `networking.hostId` (random 8 hex). `boot.zfs.forceImportRoot` as on nixPC.
- Peripheral firmware (Wi-Fi etc.): read from the Mac's own ESP (`/boot/vendorfw/firmware.cpio`, put there by the Asahi installer). **Never copied into the repo.** Since flakes can't read absolute paths in pure mode, nixAir is built with `--impure` (or an equivalent that keeps firmware out of git).
- Networking: `networking.wireless.iwd.enable = true` with iwd's built-in DHCP (`EnableNetworkConfiguration`); persist `/var/lib/iwd`.
- Persist list: same as nixPC, minus Steam directories, plus `/var/lib/iwd`.
- Laptop basics: battery/power reporting (upower), suspend, backlight and keyboard brightness keys, touchpad. Keyboard layout same as nixPC (`pl` / `dvp`, `caps:shiflock`); Hyprland binds use keycodes already.
- Display: internal panel `eDP-1`; HiDPI scale suitable for the 13.6" panel. The notch handling from the Arch setup is out of scope.
- Not on nixAir: `tpm.nix` (no TPM), `monero.nix`, Steam/gamescope/gamemode, Intel kernel params/modules, tor-browser, bazecor.
- Printer/scanner (`hardware.printers`, `hardware.sane` airscan, `pixma-scan`) stay on **both** (network devices) — move them out of nixPC's `hardware-configuration.nix` into a shared module. (Claude's call.)

### nixPC changes

- Kernel: newest kernel package set for which `zfs_2_4`/current ZFS is not broken (standard NixOS-wiki pattern filtering `linuxKernel.packages` by `zfs.meta.broken` and picking the highest version).
- Everything else moves into the new layout unchanged. The build output for nixPC should differ from today's only by the kernel and package updates from the new lock.

## Disk & install plan (nixAir)

1. **macOS (Andrew):** run the Asahi installer, "Install an OS into free space" → **UEFI environment only**, name it `NixOS`. It creates a stub macOS + new ESP in the free gap (~3 GB). Do **not** resize macOS again. Complete the recovery-mode step (permissive security for that boot object).
2. **Partition:** create **one** GPT partition in the remaining free space (`sgdisk -n` with explicit start/end inside the gap, type BF00/8300), recorded by PARTUUID. This step is done manually and shown to Andrew before running.
3. **disko** for nixAir describes **only that partition**: `disk.nix.device = "/dev/disk/by-partuuid/<uuid>"` with content `type = "zfs"; pool = "mpool"` directly — no `gpt` content anywhere. The new ESP (from step 1) is mounted at `/boot` (vfat) as a plain `fileSystems` entry, never formatted by disko.
4. **Install from a custom USB installer (Andrew's choice, 2026-10-19; Arch is not modified):** the official nixos-apple-silicon ISO has no ZFS, so the flake gets an extra output: an installer image built from nixos-apple-silicon's `iso-configuration` with ZFS enabled, using **the same kernel + ZFS package set as nixAir** (so the pool is created by exactly the ZFS version nixAir boots). Built locally on the Mac (aarch64, no remote builders). Written to the USB stick **`USB FLASH DRIVE`, serial `198C1D3329D9`, 3.7 GB** (checked empty — only Windows' `System Volume Information`; safe to wipe), addressed by `/dev/disk/by-id`, command shown to Andrew first. The image must fit in 3.7 GB.
   - Build the full nixAir system on Arch first. In the installer, install **without rebuilding** the kernel/ZFS: mount Arch's root (`nvme0n1p5`) **read-only** and use its `/nix/store` as a substituter (or an equivalent that reuses the closure built on Arch), plus cache.nixos.org over Wi-Fi (iwd in the installer; firmware is loaded from the ESP).
   - In the installer: run nixAir's disko (format+mount on the partition only), mount the new ESP at `/mnt/boot`, `nixos-install --flake <repo>#nixAir --impure`, copy the repo to `/mnt/persist/home/andrew/nixos` (or wherever `~/nixos` persists), export the pool cleanly.
   - Step 2 (creating the partition) can be done from Arch beforehand; it needs no ZFS.
5. Reboot; pick `NixOS` in the boot picker (hold power). Arch remains bootable via its own entry.

Every command that writes to the internal disk is shown to Andrew with the target identified by PARTUUID/by-id before it runs; Claude does not run them unattended.

## Verification

- `nix build .#nixosConfigurations.nixAir.config.system.build.toplevel` succeeds on the Mac (native aarch64).
- `nixPC` toplevel evaluates (and builds where feasible; x86_64 builds can't run natively here — evaluation + `nix build --dry-run` on the Mac, real build on the workstation).
- `nix eval` assertions: nixAir has no `safe/xmr`, no monero/steam/tpm services; nixPC still has them.
- disko for nixAir: inspect generated script (`disko --dry-run`/`_create` script) and confirm it references only the PARTUUID device.
- Custom installer image builds locally (`--option builders ""`), is ≤ 3.7 GB, and has the `zfs` module for its kernel (`modinfo zfs` in the image's closure).

## Left to the builder

- Exact module split and file names; option names for per-host HM packages.
- The kernel-selection expression for nixPC.
- How `--impure` / firmware path is wired (flake-level or `nixos-rebuild` alias).
- Hyprland monitor scale value and any Mac-specific HM tweaks (touchpad natural scroll etc.).
- Whether changes land as one commit or a series (nothing is committed or pushed without Andrew asking).
