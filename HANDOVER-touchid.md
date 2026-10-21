# Touch ID on nixAir — handover

Written 2026-10-21 from a macOS-side session on this exact machine. Read this
before touching `hosts/nixAir/touchid.nix`.

## Status (2026-10-21 evening): working

Steps 1–4 below are done and Touch ID works on this J413: right index finger
enrolled, `fprintd-verify` matches, `sudo` accepts the finger, and after a reboot
the templates are restored (`restore master/owner/user catacomb … Restored`,
`identity count 1`) and the finger still verifies. Merged into `master`.
Only step 5 (report upstream) is open. What it took beyond the plan:

- **Kernel source hash was wrong** in `touchid/linux-asahi-sep.nix`; corrected
  after checking the fetched tree (7.1.9 Makefile, `sep.rs`, J413 DT with Mesa on
  spi2, GPIO 178, `apple/mesacal-j413.bin`).
- **`trusted.source=applesep`** on the kernel command line. The Asahi config
  builds in the TPM and TEE trusted-key sources; the trusted core binds the first
  one at boot, so the SEP source hit `trusted-keys: registration failed (EBUSY)`
  and step 4's seal/unseal could not work.
- **SEP units are never restarted by `nixos-rebuild switch`**
  (`restartIfChanged`/`stopIfChanged = false`). Flipping `xartWrites` made switch
  restart the loader on a driver already loaded read-only (parameters are fixed
  at load), so it looped on the seal/unseal probe until its 120 s timeout. Harmless,
  but exactly what the rules below forbid. Use `nixos-rebuild boot` + reboot for
  anything that changes these units.
- **OS UUID pinned** in `hosts/nixAir/default.nix`:
  `apple_sep.os_uuid_hi=4099658544154233333 apple_sep.os_uuid_lo=13248823857061546668`
  (= m1n1's apfs-preboot-uuid `38E4E9B9-98B5-49F5-B7DD-471A4BDFCAAC`, big-endian
  halves; the driver logs `using explicit OS UUID 38e4e9b998b549f5-b7dd471a4bdfcaac`).
- **Polkit agent**: no agent was running, so `fprintd-enroll` failed with
  `Not Authorized: net.reactivated.fprint.device.enroll`. `hyprpolkitagent` now
  runs (home/hyprland.nix).
- **PAM**: login is password-only (`security.pam.services.login.fprintAuth =
  false`); sudo, su and polkit take the finger.

Expected messages that look like errors but are not:
- Read-only mode (`xartWrites = false`): `Touch ID activation failed: ENOENT`
  (no keybag can exist without writes), then `EIO` (no retries this boot).
- Before the first enrolment: `matching unavailable this boot … template state is
  unproven` (no catacomb files yet). Gone once a finger is enrolled and rebooted.
- Early `trusted-keys: seal failed (ENODEV)` lines: the loader polling before the
  key store endpoint (0x12) is up.

Open, minor: at boot the loader can check for `/dev/sep-bio` a moment too early
("trusted keys are ready; no biometric device is present"), so
`aurora-sep-ready` is skipped; fprintd still brings the sensor up on first use.
Full report with the hardware evidence:
https://claude.ai/code/artifact/699bdfb4-6287-4d41-8d61-c522dc9d5fc4

## The machine

MacBook Air 13" M2 2022 — `Mac14,2`, board `J413AP`, SoC `T8112`. macOS 26.5.2
on the same disk (dual boot via the Asahi stub volume "NixOS", ESP `87A7-1509`).
Fingerprint sensor: Apple "Mesa" on `spi2`, sensor id `0x3352`, patch version 22.

## What this branch does

Touch ID matching happens inside the Secure Enclave (SEP). Linux never sees a
fingerprint image; it asks the enclave to enrol and verify. Three layers on top
of the stock Asahi stack from nixos-apple-silicon — nothing else is replaced:

| Layer | What | Where |
|---|---|---|
| Kernel | `linux-asahi` rebuilt from `aurora-silicon/linux` branch `feat/sep` (Asahi 7.1.9 + the Rust `apple_sep` driver, `/dev/sep-bio`, ioctl ABI v4) | `hosts/nixAir/touchid/linux-asahi-sep.nix` |
| Bootloader | m1n1 2.0.0 + one patch: on M2+ do not query the SEP for the RNG seed (it breaks the sensor registration iBoot hands over) and forward `apfs-preboot-uuid` to the FDT | `hosts/nixAir/touchid/m1n1-v2.0.0-sep-warm-registration.patch` |
| Userspace | libfprint 1.94.100 + Aurora's `aurora` driver; loader, calibration and readiness services; fprintd stock | `hosts/nixAir/touchid.nix`, `hosts/nixAir/touchid/aurora-sep/` |

Switch: `my.touchid.enable = true` in `hosts/nixAir/default.nix`.
Gate: `my.touchid.xartWrites` — **true since 2026-10-21** (after the read-only boots passed). See "Order of operations".

## Hardware facts already verified from macOS (do not re-derive)

Every value the Linux J413 device tree hard-codes was checked against this Mac's
own device tree (Apple Device Tree via IORegistry) and matches: SEP mailbox
`0x25e400000/0x6c000`, SEP DART `0x25d2c0000` (vm `0x4000` + `0xffff0000`),
warm handoff (`sepfw-booted=1`), `spi2 @ 0x235108000` native CS0, 8 MHz, 20 ns
CS setup/hold, power GPIO 178 active-high, data-ready GPIO 177 (polled, not
wired in DT). SPI mode 1 (`spi-cpha`) is correct: the macOS kexts were
disassembled; AppleSPIMC takes only bit 0 of the "clock phase 3" byte as CPHA
with CPOL 0. Calibration source word 3 = "FDR" matches what macOS uses here.

Upstream (aurora-silicon/linux PR 152) validated this profile only on the
15" J415 and marked J413 untested. This machine is the missing data point.

## State on the macOS side (Andrew's Mac, `~/touchid-nixos/`)

- `isc-j413-backup.img` — raw copy of `disk0s1` (iBootSystemContainer, 500 MB),
  sha256 `fc2c26626b77b80e125683a05338ca91e044723b8fb2bfb1811ce644874dbf7d`,
  also on Google Drive. **This is the rollback for anything xART-related.**
- `mesacal-j413.bin` — this sensor's calibration blob (64052 B, sha256
  `1ddb22a7a12e837244b683706603b08b2358e6b05062f3736ce4d0f74d79b1ff`), also on
  Drive. Linux regenerates it from the partition on its own; keep this copy to
  compare hashes (`sha256sum /var/lib/aurora-sep/mesa-calibration.bin`).
- Read-only xART inspection of the image: one `.gl` file, single unencrypted
  6 MiB extent at APFS block 1236, 12 live records all CRC-valid, no snapshots.
  That is exactly the layout the driver's `xart_writes=1` ownership gate accepts.

## Order of operations

1. **Build first, don't switch.** The kernel is a full Rust-enabled Asahi build
   (an hour or more on the Air; a remote aarch64 builder helps).
   ```sh
   nixos-rebuild build --flake .#nixAir --impure
   ```
   Things that can fail here and what they mean:
   - ZFS module "does not support the Asahi kernel": the assertion in
     `hosts/nixAir/default.nix`. 7.1.9 is inside ZFS 2.4.4's range (≤ 7.2), so
     this would mean the nixpkgs pin moved; check `boot.zfs.package.version`.
   - `rustc`/`bindgen` version complaints: nixpkgs' Rust must be new enough for
     7.1.9; Asahi 7.1.13 builds with the same pin, so this is unlikely.
   - libfprint patch rejects: the three patches were applied in order against
     `v1.94.100` on 2026-10-21 and applied cleanly.
   - m1n1 patch reject: rebased onto nixpkgs' m1n1 2.0.0 and `git apply --check`ed.
2. **Switch and reboot** (new kernel + new m1n1 both need a reboot).
3. **Read-only verification** (`xartWrites = false`, the state of this branch):
   ```sh
   journalctl -b -u aurora-sep -u aurora-sep-ready -u fprintd
   journalctl -b -k | grep -iE 'apple_sep|sep-bio|mesa|sbio'
   ls -l /dev/sep-bio
   sudo /run/current-system/sw/libexec/aurora/sensor-present && echo "sensor present"
   ```
   Expected in `dmesg`: the SEP endpoint ladder climbing to `0x12` (key store),
   a DART changeset applied, hwrng registered, the Mesa sensor bound in
   mode 1, calibration blob loaded (`LOAD_CALIBRATION` ok), `/dev/sep-bio`
   created. The driver will log that captures are refused while xART writes
   are off — that is correct for this stage. Also check m1n1 did its part:
   `cat /sys/firmware/devicetree/base/chosen/apfs-preboot-uuid` must print a
   UUID (the NixOS stub's, not macOS's `E4457EB3-…`).
4. **Only then** set `my.touchid.xartWrites = true`, rebuild, reboot. The loader
   now runs `modprobe apple_sep xart_writes=1 provision_keybag=1`, waits for a
   trusted-key seal/unseal round trip, and `aurora-sep-ready` warms up
   `/dev/sep-bio`. Then:
   ```sh
   fprintd-enroll      # 8 stages, guidance comes from the enclave
   fprintd-verify
   sudo -k; sudo true  # pam_fprintd is on for all services once fprintd is enabled
   ```
   Reboot and verify again: persistence across reboots is the real test.
5. Report the J413 result upstream (aurora-silicon/linux, referencing PR 152):
   sensor id `0x3352`, SPI mode 1 confirmed from the kext, enrol/verify/reboot.

## Rules

- **Never** `modprobe -r apple_sep` or restart `aurora-sep.service` to retry.
  The SEP handoff happens once per boot; reboot instead.
- **Never** restore the raw iBoot container image "to undo" an enrolment while
  macOS has booted since: the enclave keeps anti-replay counters. The backup is
  for a damaged partition, not for time travel. Read `touchid/aurora-sep/XART-SAFETY.md`.
- Keep the OS identity stable once enrolments exist: pin
  `apple_sep.os_uuid_hi=… apple_sep.os_uuid_lo=…` on the kernel command line to
  the UUID the driver logs on first provisioning, so a bootloader change cannot
  orphan the templates.
- Persisted state (impermanence): `/var/lib/aurora-sep`, `/var/lib/fprint`, and
  the six driver files under `/var/lib/*.bin` which are symlinks into
  `/persist/sep-state` (tmpfiles). Back `/persist/sep-state` up root-only;
  never copy it to another machine.
- The calibration blob lands in `/lib/firmware/apple/mesacal-j413.bin`
  (recreated every boot). NixOS's `firmware_class.path` is the read-only store,
  so the kernel's `/lib/firmware` fallback search is used instead.

## Known gaps

- Sleep/resume with a capture in flight is the one T8112 path upstream has not
  exercised. Expect to need the fprintd stop-before-suspend hook if it misbehaves.
- The data-ready IRQ (GPIO 177) is left out of the DT upstream; the driver polls.
  Adding `interrupts` to the `&mesa` node is a small follow-up once capture works.
- With `services.fprintd.enable`, NixOS turns on `pam_fprintd` for every PAM
  service. Before enrolment it fails fast and falls through to the password;
  if the prompt order annoys, set `security.pam.services.<name>.fprintAuth = false`.

## Sources

- https://github.com/aurora-silicon/linux (branch `feat/sep`, pinned rev `120e030e`), PR 152, tools/aurora-sep
- https://github.com/aurora-silicon/m1n1/pull/3 (original warm-registration patch)
- https://github.com/aurora-silicon/nixos-aurora (`modules/sep.nix`, `sep/` — the services here are adapted from it)
- https://asahilinux.org/docs/hw/soc/sep/
