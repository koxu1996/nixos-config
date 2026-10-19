# nixAir Host Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `~/nixos` (nixos-config) into a two-host flake — `nixPC` (x86_64 workstation, behaviour unchanged except kernel) and `nixAir` (MacBook Air M2, ZFS + impermanence) — and install nixAir into the free space on the Mac's disk from a custom ZFS-enabled USB installer.

**Architecture:** Shared NixOS modules in `modules/`, shared Home Manager in `home/`, per-host files in `hosts/<name>/`. nixAir adds the `nixos-apple-silicon` input. A third output, `installer-nixAir`, is an ISO built from nixos-apple-silicon's installer module plus ZFS on nixAir's exact kernel. Installation copies a closure pre-built on Arch; nothing is compiled in the installer.

**Tech Stack:** Nix flakes, NixOS (nixos-unstable), Home Manager, impermanence, disko, nixos-apple-silicon, OpenZFS 2.4.

**Spec:** `docs/superpowers/specs/2026-10-17-nixair-host-design.md`

## Global Constraints

- **Every** `nix build` / `nix eval` / `nixos-*` command runs with `--option builders ""` (nixbuild.net is configured in `/etc/nix/nix.conf` and must never be used). nixPC is evaluated only, never built here.
- The Mac's internal disk: only the new ZFS partition (by PARTUUID) is ever formatted, and only from the installer. `nvme0n1p1`–`p6` and the new ESP created by the Asahi installer are never formatted. No disko config contains `type = "gpt"` for the Mac. Every command that writes to a disk or USB device is shown to Andrew and run by him (they need sudo); the executor never runs them.
- nixAir pool name `mpool`, `ashift=12`, root fs options as nixPC (`compression=lz4 atime=off acltype=posixacl xattr=sa mountpoint=none`), datasets `local/root` (+ `@blank`), `local/nix`, `local/tmp` (`quota=16G sync=disabled redundant_metadata=none`), `safe/persist`; **no** `safe/xmr`. `networking.hostId = "a35dc981"`.
- Hostnames: `nixPC`, `nixAir`. Passwords: `initialPassword = "pass"` for root and andrew on both (unchanged).
- nixAir only: iwd with built-in DHCP; no monero.nix, tpm.nix, Steam/gamescope/gamemode, tor-browser, bazecor, Intel kernel params. monero-gui stays on both.
- nixPC: `boot.kernelPackages` = newest `pkgs.linuxKernel.packages.linux_X_Y` whose ZFS module is not broken. Everything else behaves as today.
- Apple firmware never enters git. nixAir is built with `--impure`; the firmware path is resolved from the first existing of `/boot/vendorfw`, `/mnt/boot/vendorfw`, `/boot/efi/vendorfw` (the last one is Arch's ESP — same machine, same firmware).
- Commits: local only, never pushed. The executor stages changes and commits only after Andrew says to commit (his standing rule). "Commit" steps below mean "ask Andrew, then commit".
- Baseline before any change: `nixosConfigurations.nixPC.config.system.build.toplevel.drvPath` = `/nix/store/zdpm2yi5lssxgwgy6zghg0yzy7k0pi7c-nixos-system-nixPC-26.11.20261006.151fa4e.drv`, kernel `6.12.112`, nixpkgs rev `151fa4e8` (2026-10-06).

## Review Focus

1. **Restructure silently changes nixPC** — a moved module dropped or double-imported. Expected: identical drvPath before the lock/kernel change (Task 1 test).
2. **disko touches more than the partition** — e.g. a stray `gpt` or the ESP in disko. Expected: generated create script references only `/dev/disk/by-partuuid/<uuid>` (Task 3 test).
3. **ZFS silently missing on nixAir/installer** — kernel ahead of ZFS makes the module broken and the build either fails late or drops ZFS. Expected: eval-time failure with a clear message; `zfs.ko` present in both closures (Tasks 3–5 tests).
4. **Firmware path not found on Arch** → apple-silicon assertion "firmware location appears incorrect". Expected: nixAir builds on Arch via `/boot/efi/vendorfw` (Task 4 test).
5. **Installer image too big for the 3.7 GB stick.** Expected: ISO ≤ 3,700,000,000 bytes (Task 5 test).

---

### Task 1: Restructure into hosts/modules/home with nixPC unchanged

**Files:**
- Create: `hosts/nixPC/default.nix` (imports; hostname, hostId `666ab666`, kernel pin, i915 params, Steam/gamescope/gamemode, `security.pki` cert stays shared), `hosts/nixPC/hardware-configuration.nix` (moved from root, minus printer/scanner), `hosts/nixPC/disko.nix`, `hosts/nixPC/monero.nix`, `hosts/nixPC/tpm.nix` (moved)
- Create: `modules/base.nix` (everything host-independent from `configuration.nix`), `modules/zfs-impermanence.nix` (rollback-root service, parameterised by option `my.zfs.pool` (str); persist.nix import), `modules/persist.nix` (moved; Steam dirs moved into nixPC via `environment.persistence."/persist".users.andrew.directories` in `hosts/nixPC/default.nix`), `modules/printing.nix` (CUPS, `hardware.printers`, `hardware.sane` airscan block, avahi, ensure-printers tweak)
- Create: `home/default.nix` (from `home.nix`), move `hyprland.nix waybar.nix gpg-tools.nix thunderbird.nix pixma-scan.nix` into `home/`; option `my.home.extraPackages` not needed — nixPC-only packages (`tor-browser`, `bazecor`) go in `hosts/nixPC/home.nix`, imported via `home-manager.users.andrew.imports`
- Modify: `flake.nix` — `mkHost = { name, system, modules }` helper; `nixosConfigurations.nixPC` built from it; `certs/` stays at root
- Delete: root `configuration.nix`, `hardware-configuration.nix`, `persist.nix`, `home.nix` etc. after moving

**Interfaces:**
- Produces: `mkHost` in `flake.nix`; module option `my.zfs.pool : str` (rollback service runs `zfs rollback -r ${pool}/local/root@blank`, after `zfs-import-${pool}.service`); `modules/{base,zfs-impermanence,persist,printing}.nix`; `home/default.nix`.

- [ ] **Step 1: Test — nixPC derivation identical.** Run `nix eval --raw --option builders "" .#nixosConfigurations.nixPC.config.system.build.toplevel.drvPath`. Expected after the restructure: exactly the baseline drvPath from Global Constraints. (Before the change it already equals the baseline; this is the regression guard.)
- [ ] **Step 2: Move files and write `mkHost`/module split as above.** `git mv` for moved files so history follows.
- [ ] **Step 3: Run Step 1's command.** Expected: baseline drvPath. If it differs, diff with `nix-diff` (`nix run nixpkgs#nix-diff --option builders "" -- <old.drv> <new.drv>`) until identical. The only acceptable remaining difference is the *order* of persisted directories (Steam entries now merged from the host module); show that nix-diff to Andrew and note it in the commit message.
- [ ] **Step 4: Commit** (after Andrew's OK): `refactor: split config into hosts/, modules/, home/`.

### Task 2: nixPC — lock update and newest ZFS-compatible kernel

**Files:**
- Modify: `flake.lock` (`nix flake update --option builders ""`)
- Modify: `hosts/nixPC/default.nix` — replace `boot.kernelPackages = pkgs.linuxPackages_6_12;` and its comment

**Interfaces:**
- Produces: nothing new for later tasks.

- [ ] **Step 1: Test.** `nix eval --raw --option builders "" .#nixosConfigurations.nixPC.config.boot.kernelPackages.kernel.version` — expected today: starts with `7.2.` (currently 6.12.112 → fails the expectation). Also `nix eval --json … .config.boot.kernelPackages.${zfsAttr}.meta.broken` where `zfsAttr = config.boot.zfs.package.kernelModuleAttribute` → `false`.
- [ ] **Step 2: Implement.** Kernel selection: filter `pkgs.linuxKernel.packages` to names matching `linux_[0-9]+_[0-9]+`, whose evaluation succeeds (`builtins.tryEval`) and whose `${config.boot.zfs.package.kernelModuleAttribute}.meta.broken` is false; pick the highest `kernel.version` (`lib.versionOlder`). Keep `boot.zfs.forceImportRoot = true`. Then `nix flake update`.
- [ ] **Step 3: Run Step 1.** Expected: `7.2.x`, `false`. Toplevel drvPath evaluates without error.
- [ ] **Step 4: Commit** (after OK): `nixPC: newest ZFS-compatible kernel; update flake.lock`. Note in the message that Andrew builds/switches on the workstation (`sudo nixos-rebuild boot --flake ~/nixos#nixPC`, reboot, old generation stays in the menu).

### Task 3: nixAir host configuration

**Files:**
- Modify: `flake.nix` — input `nixos-apple-silicon.url = "github:nix-community/nixos-apple-silicon"` (follows nixpkgs only if its README says that's supported; otherwise not); `nixosConfigurations.nixAir = mkHost { name = "nixAir"; system = "aarch64-linux"; … }` with `nixos-apple-silicon.nixosModules.apple-silicon-support`
- Create: `hosts/nixAir/default.nix` — hostname, hostId `a35dc981`, `my.zfs.pool = "mpool"`, `boot.loader.systemd-boot.enable = true`, `boot.loader.efi.canTouchEfiVariables = false`, `boot.supportedFilesystems.zfs = true`, `hardware.asahi.peripheralFirmwareDirectory` per Global Constraints, iwd (`networking.wireless.iwd.enable`, `settings.General.EnableNetworkConfiguration = true`), persist `/var/lib/iwd`, upower, an assertion that `config.boot.kernelPackages.${config.boot.zfs.package.kernelModuleAttribute}.meta.broken == false` with message "ZFS does not support the Asahi kernel ${version}"
- Create: `hosts/nixAir/hardware-configuration.nix` — `fileSystems` for `/` (`mpool/local/root`), `/nix`, `/tmp`, `/persist` (`neededForBoot`), `/etc/nixos` bind from `/home/andrew/nixos`, `/boot` = vfat `by-uuid` from `hosts/nixAir/disk-ids.nix`
- Create: `hosts/nixAir/disk-ids.nix` — `{ espUuid = "0000-0000"; zfsPartUuid = "00000000-0000-0000-0000-000000000000"; }` placeholders, filled in Task 6
- Create: `hosts/nixAir/disko.nix` — `disko.enableConfig = false`; `disk.nix = { type = "disk"; device = "/dev/disk/by-partuuid/${zfsPartUuid}"; destroy = false; content = { type = "zfs"; pool = "mpool"; }; }`; `zpool.mpool` per Global Constraints
- Create: `hosts/nixAir/home.nix` — Hyprland monitor `eDP-1` scale (Claude's choice, e.g. 1.6 for 2560×1664), touchpad natural scroll

**Interfaces:**
- Consumes: `mkHost`, `my.zfs.pool`, shared modules from Task 1.
- Produces: `nixosConfigurations.nixAir`; `hosts/nixAir/disk-ids.nix` with keys `espUuid`, `zfsPartUuid`.

- [ ] **Step 1: Tests** (all `--impure --option builders ""`; fail now because nixAir doesn't exist):
  - `nix eval --raw .#nixosConfigurations.nixAir.config.networking.hostName` → `nixAir`
  - `nix eval --json .#nixosConfigurations.nixAir.config.disko.devices.zpool.mpool.datasets --apply builtins.attrNames` → `["local","local/nix","local/root","local/tmp","safe","safe/persist"]`
  - `nix eval --json .#nixosConfigurations.nixAir.config.services.monero.enable` → `false`; `.programs.steam.enable` → `false`; `.security.tpm2.enable` → `false`; `.networking.wireless.iwd.enable` → `true`
  - `nix eval --json .#nixosConfigurations.nixPC.config.services.monero.enable` → `true` (nixPC unaffected)
  - Disko safety: `nix build --impure --option builders "" --no-link --print-out-paths .#nixosConfigurations.nixAir.config.system.build.formatScript` then `grep -o '/dev/[^ "]*' <script> | sort -u` → only `/dev/disk/by-partuuid/00000000-…`; `grep -c 'sgdisk\|parted\|mkfs' <script>` → `0`.
- [ ] **Step 2: Implement the files above.**
- [ ] **Step 3: Run Step 1's tests.** All expected values.
- [ ] **Step 4: Commit** (after OK): `add nixAir host (MacBook Air M2, ZFS)`.

### Task 4: Build nixAir locally

**Files:** none (build only; fix anything the build reveals in Task 3's files).

- [ ] **Step 1: Build.** `nix build --impure --option builders "" --print-out-paths .#nixosConfigurations.nixAir.config.system.build.toplevel -o ~/nixair-system` (run in background; the Asahi kernel and ZFS compile locally — can take an hour+).
- [ ] **Step 2: Verify.** `ls ~/nixair-system/kernel-modules/lib/modules/*/extra/zfs.ko*` exists; `readlink ~/nixair-system/kernel` contains the linux-asahi version; `ls ~/nixair-system/firmware/lib/firmware | grep -i brcm` non-empty (Wi-Fi firmware picked up).

### Task 5: Installer image with ZFS

**Files:**
- Modify: `flake.nix` — `packages.aarch64-linux.installer-nixAir`: `nixpkgs.lib.nixosSystem` with `nixos-apple-silicon.nixosModules.apple-silicon-installer`, `{ nixpkgs.hostPlatform = "aarch64-linux"; nixpkgs.overlays = [ nixos-apple-silicon.overlays.default ]; boot.supportedFilesystems.zfs = lib.mkForce true; networking.hostId = "a35dc981"; environment.systemPackages = [ disko.packages.aarch64-linux.default ]; }`, output `config.system.build.isoImage`. Kernel and ZFS package must be the same as nixAir's (same nixpkgs + overlay → same derivations).
- Create: `hosts/nixAir/install.sh` — the in-installer script for Task 7 (see there).

**Interfaces:**
- Produces: `.#installer-nixAir` (ISO in `result/iso/*.iso`).

- [ ] **Step 1: Tests (fail now):** after build, `stat -c %s result/iso/*.iso` ≤ `3700000000`; `nix eval --raw … .#installer-nixAir.config.boot.kernelPackages.kernel.drvPath` (use `passthru.config` or the nixosSystem config) equals nixAir's kernel drvPath; the ISO's closure contains `zfs.ko` (`nix path-info -r <iso drv output> | xargs ls -d 2>/dev/null | grep -l` or check `config.boot.extraModulePackages`/`system.build.kernel` for zfs).
- [ ] **Step 2: Implement output; build** with `--option builders ""`.
- [ ] **Step 3: Run tests.** If over 3.7 GB, set `isoImage.squashfsCompression = "zstd -Xcompression-level 19"` and drop optional docs.
- [ ] **Step 4: Commit** (after OK): `add ZFS-enabled installer image for nixAir`.

### Task 6: Disk preparation (Andrew + Claude, needs the macOS step)

**Files:** Modify `hosts/nixAir/disk-ids.nix`.

- [ ] **Step 1 (Andrew, macOS):** Asahi installer → `f` → "UEFI environment only" → name `NixOS`; recovery-mode permissive-security step.
- [ ] **Step 2 (Claude, read-only):** `lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTUUID,UUID /dev/nvme0n1` and the sysfs start/size listing. Expected: `p1`–`p6` unchanged (sizes as in spec), one new small APFS stub + one new vfat ESP containing `vendorfw/firmware.cpio`, and one remaining free gap of roughly 415 GB. Record the new ESP's vfat UUID.
- [ ] **Step 3 (Claude prepares, Andrew runs with sudo):** `sgdisk -n 0:<gapStart>:<gapEnd> -t 0:BF00 -c 0:nixair-zfs /dev/nvme0n1` with explicit sector numbers inside the remaining gap (2048-sector aligned), then `partprobe`. Show `sgdisk -p` before/after; only one new entry may appear.
- [ ] **Step 4:** Fill `espUuid` and `zfsPartUuid` (from `lsblk -o PARTUUID`) into `disk-ids.nix`; rerun Task 3 tests (disko script now names the real PARTUUID) and rebuild Task 4 (`~/nixair-system` updated).
- [ ] **Step 5: Commit** (after OK): `nixAir: real ESP and ZFS partition ids`.

### Task 7: Write USB, install, first boot

**Files:** `hosts/nixAir/install.sh` (created in Task 5), finalised here.

- [ ] **Step 1 (Claude):** export the closure as a binary cache on Arch: `nix copy --option builders "" --to file:///home/andrew/nixair-cache $(readlink -f ~/nixair-system)`; record the toplevel store path into `/home/andrew/nixair-cache/TOPLEVEL`.
- [ ] **Step 2 (Andrew, sudo):** `dd if=result/iso/<iso> of=/dev/disk/by-id/usb-USB_FLASH_DRIVE_198C1D3329D9-0:0 bs=4M conv=fsync status=progress` (exact by-id name confirmed with `ls -l /dev/disk/by-id | grep 198C1D3329D9` first).
- [ ] **Step 3: `install.sh` contents** (run as root in the installer; `set -euo pipefail`; prints each step):
  1. `mount -o ro /dev/disk/by-partuuid/<p5 PARTUUID> /arch` (Arch root, read-only).
  2. `disko --mode format,mount` with `/arch/home/andrew/nixos/hosts/nixAir/disko.nix` (format + mount only — never `destroy`).
  3. `mkdir -p /mnt/boot && mount /dev/disk/by-uuid/<espUuid> /mnt/boot`.
  4. `nix copy --from file:///arch/home/andrew/nixair-cache --to /mnt --no-check-sigs $(cat /arch/home/andrew/nixair-cache/TOPLEVEL)`.
  5. `nixos-install --system <toplevel> --no-root-passwd --no-channel-copy`.
  6. `mkdir -p /mnt/persist/home/andrew && cp -a /arch/home/andrew/nixos /mnt/persist/home/andrew/nixos && chown -R 1000:100 /mnt/persist/home/andrew` (uid of andrew on NixOS: check `config.users.users.andrew.uid` or leave ownership to first boot's activation — Claude's call, verify).
  7. `umount -R /mnt; zpool export mpool; umount /arch`.
- [ ] **Step 4 (Andrew):** boot the stick (U-Boot picks USB on the NixOS entry), connect Wi-Fi not needed, run `install.sh`, reboot, choose `NixOS` in the boot picker.
- [ ] **Step 5: Verify on nixAir** (Andrew pastes output): `hostname` → `nixAir`; `zfs list` shows the six datasets; `uname -r` = Asahi kernel; `iwctl station wlan0 get-networks` lists networks; reboot once and confirm a file created in `/` (outside persist) is gone and `~/nixos` remains. Holding power and choosing the Arch entry still boots Arch.
- [ ] **Step 6:** Cleanup on Arch (Claude): delete `~/nixair-cache`, `~/nixair-system` link; nothing else on Arch was changed.
