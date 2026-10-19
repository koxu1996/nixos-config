# Shared Look Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the Mac's Quickshell bar, lime palette, terminal and Hyprland behaviour from the Arch Home Manager config into `~/nixos` as shared Home Manager modules for `nixPC` and `nixAir`, with per-host features, replacing the workstation's waybar/mako/Snazzy/wlsunset look.

**Architecture:** A `home/look/` module tree owns everything visual: the Quickshell bar source, the palette, the terminal, and the shared Hyprland behaviour (merged into the existing `home/hyprland.nix`). Per-host differences are Home Manager options under `my.look.*`, rendered into a generated `Host.qml` singleton that is added to the bar's source at build time; hosts set the options, the QML reads `Host.*`. Root helpers (`cpu-profile`) are NixOS modules. The Arch-only Wi-Fi backend (netctl + `wifi-ctl`) is replaced by an iwd backend whose parsing lives in a plain JS file tested with node.

**Tech Stack:** NixOS/Home Manager (nixos-unstable), Quickshell 0.3.x (QML), Hyprland 0.56 Lua config, hyprsunset, iwd D-Bus via `busctl --json`, polkit, node (tests only).

**Spec:** `docs/superpowers/specs/2026-10-19-shared-look-design.md`

## Global Constraints

- Source of the look: the **live working tree** of `~/.config/home-manager` (Arch) at the start of Task 1 — read-only; Arch keeps using it. Not a word-for-word copy: port what the look needs, drop Arch-only pieces, fold duplicates into the repo's existing modules (Andrew: "be smart about moving it").
- Every `nix` command: `--option builders ""` (nixbuild.net must never be used). nixAir needs `--impure`. nixPC is evaluated only on the Mac; Andrew builds/switches it on the workstation.
- Commits only when Andrew says; Andrew pushes (no GitLab key in Claude's shell).
- Per-host table (spec): nixAir — wifi (iwd), battery, glow brightness, CPU profiles in the battery panel, notch gap 200. nixPC — no wifi, no battery, no glow brightness, CPU profiles in the CPU/MEM panel, notch gap 0. Glow colour temperature on both, one shared `glow/profiles.json` (Warsaw 52.23/21.01, 6500/4000/2700 K).
- Removed from both: waybar (incl. `custom/voice` and tray), mako, Snazzy Alacritty, the old tmux config, `wlsunset`, the fzf-in-alacritty `appLauncher`.
- Kept on nixPC: Steam/gamescope/gamemode, monero, tpm-fido, printing/scanning, Syncthing, Tailscale, gpg tools, hy3, `pl`/`dvp` + `caps:shiflock`, keycode binds.
- nixAir gains kernel params `appledrm.show_notch=1` and `brcmfmac.feature_disable=0x82000`.
- Workstation CPU profiles (i7-9700, intel_pstate): saver = governor `powersave`, EPP `power`, `no_turbo=1`; balanced = `powersave`, `balance_performance`, `no_turbo=0`; performance = `performance`, `performance`, `no_turbo=0`. Same CLI as the M2 helper: `cpu-profile saver|balanced|performance`, plus `cpu-profile` with no argument printing the current profile name (if the M2 helper doesn't have that, the bar's existing detection is kept per host).
- Terminal behaviour follows the Mac's `terminal.nix` (spec: "behaviour the same"), including its tmux pane binds `h/t/n/s` (Dvorak) — this replaces the workstation's `hjkl`/`j` binds.
- Persist (both hosts, `modules/persist.nix`): `.local/state/quickshell` (Glow mode, notification history/DND).

## Review Focus

1. **A widget silently errors at runtime** (QML type error, missing command) — the build passes but the bar shows a blank chip. Expected: `qmllint` clean on all bar files (Task 2) and every external command the bar runs is in the bar's PATH (Task 3 test).
2. **nixPC regains Mac-only UI** (Wi-Fi/battery chip, notch gap, brightness slider) because a `Host.*` flag isn't checked in one place. Expected: generated Host.qml per host matches the table and each gated component checks it (Task 2 tests).
3. **Keybinding collisions** between the shared Mac binds and nixAir's host binds (function row, mainMod+Shift+S) or the workstation's Steam/game use of Print/backtick. Expected: no key bound twice in the generated Lua per host (Task 5 test).
4. **iwd permissions / passphrase flow** — scan/list work but connecting to a new PSK network fails or prompts. Expected: join uses `iwctl --passphrase` non-interactively; parser handles hidden, open, known, connected networks (Task 7 tests).
5. **State lost on reboot** on impermanent hosts (Glow manual mode, DND, notification history). Expected: `.local/state/quickshell` persisted (Task 3 test).

---

### Task 1: Import the look into `home/look/`

**Files:**
- Create: `home/look/quickshell/` — from Arch `quickshell/bar/` (all QML, `waves.frag`, `tools/screenshot.sh`), `quickshell/launcher/launcher.json`, `quickshell/glow/profiles.json`, `quickshell/clock/config.json`; the READMEs for glow/clock/launcher (update paths to `~/nixos/home/look/...`).
- Create: `home/look/palette.nix` (from `theme/palette.nix`).
- Not imported: `quickshell/wifi/` (netctl helper, BRIEF), `quickshell/battery/` install docs (become Task 6), `quickshell/notifications/BRIEF.md`, `waybar/`, `pkgs/`, `switch.sh`.
- Create: `tests/look-manifest.txt` — the imported file list + `sha256sum` of each, as copied.

- [ ] **Step 1: Test** — add group `look_files` to `tests/check.sh`: every path in `tests/look-manifest.txt` exists under `home/look/`; `home/look/quickshell/WifiService.qml` exists; no file under `home/look/` references `/usr/local/bin/wifi-ctl` or `netctl` after Task 7 (that sub-check is added in Task 7). Run → FAIL (files missing).
- [ ] **Step 2: Copy** the files, write the manifest (`sha256sum` relative paths), `git add`.
- [ ] **Step 3: Run** `tests/check.sh look-files` → PASS.

### Task 2: Per-host options and generated `Host.qml`

**Files:**
- Create: `home/look/default.nix` — options and wiring (imports `quickshell.nix`, `terminal.nix`, later `hyprland` parts).
- Create: `home/look/quickshell.nix` — builds the bar source: `pkgs.runCommand "quickshell-bar"` copying `./quickshell` (only the bar's QML/frag/tools) and writing `Host.qml`.
- Modify: `home/look/quickshell/{shell.qml,Battery.qml,Wifi.qml,Glow.qml,GlowService.qml,SystemStats.qml}` — read `Host.*`.
- Modify: `home/default.nix` — import `./look`.

**Interfaces:**
- Produces HM options (all required unless noted):
  - `my.look.wifi : bool`, `my.look.battery : bool`, `my.look.glowBrightness : bool`,
  - `my.look.notchGap : int` (pixels; 0 = none),
  - `my.look.cpuProfile : enum [ "battery" "stats" ] | null` (where the CPU profile control is shown; null = none).
- Produces generated `Host.qml`: `pragma Singleton` (no `{` before it), `Singleton { readonly property bool wifi; battery; glowBrightness; readonly property int notchGap; readonly property string cpuProfile }` (`""` for null).
- Produces `config.my.look.barSource` (the derivation) for Task 3.

- [ ] **Step 1: Tests** (`look_host` group): for each host, `nix eval` the generated `Host.qml` text (expose it as `config.my.look.hostQml`) and assert the five values per the table; assert `shell.qml` uses `Host.notchGap` and no longer hardcodes `200`; assert `Wifi {}`/`Battery {}` in `shell.qml` are wrapped by `Host.wifi`/`Host.battery` (`grep` the `visible:`/`active:` lines); `qmllint` over the built bar source (`nix run --option builders "" nixpkgs#kdePackages.qtdeclarative -- qmllint …`, or `nix shell` with `qmllint`) reports no errors other than unresolved Quickshell imports (record the accepted warning set in the test). Run → FAIL.
- [ ] **Step 2: Implement** options, `Host.qml` generation, QML gating:
  - `shell.qml`: `notchGap: hasNotch ? Host.notchGap : 0` (keep the `eDP-1` + height ≥ 832 check).
  - `Wifi`/`Battery`: not instantiated when the flag is false (a `Loader { active: Host.wifi }` or `visible`+`enabled`; their services must not poll when off).
  - Glow: brightness rows and backlight polling only when `Host.glowBrightness`.
- [ ] **Step 3: Run tests** → PASS.

### Task 3: Bar, hyprsunset and notifications in Home Manager; old look removed

**Files:**
- Modify: `home/look/quickshell.nix` — `programs.quickshell` (configs.bar = `barSource`, activeConfig `bar`, systemd target `hyprland-session.target`), `services.hyprsunset` (`--identity`, target `hyprland-session.target`), `xdg.configFile` links for `quickshell/{launcher/launcher.json,glow/profiles.json,clock/config.json}` via `mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/home/look/quickshell/<file>"`; mako masked (or simply not enabled — choose the one that keeps D-Bus activation from starting it); the bar service's `PATH` contains every command the QML runs: `busctl` (systemd), `df` (coreutils), `rfkill` (util-linux), `tailscale`, `pkexec` (polkit), `brightnessctl` (nixAir), `iwctl` (nixAir), `grim`, `slurp`, `wl-clipboard`, `libnotify`, `hyprpaper` stays.
- Modify: `home/default.nix` — drop `services.mako`, `programs.alacritty` (moves to Task 4), `programs.tmux` (Task 4), `wlsunset` package, hyprpaper conf stays (uses `my.wallpaper`).
- Delete: `home/waybar.nix` (and its import).
- Modify: `modules/persist.nix` — add `.local/state/quickshell`.

- [ ] **Step 1: Tests** (`look_session`): both hosts: `programs.quickshell.enable` true, `programs.waybar.enable` false, `services.mako.enable` false, `services.hyprsunset.enable` true, `"wlsunset"` not in `home.packages` names; the three xdg links point to `/home/andrew/nixos/home/look/quickshell/...`; `.local/state/quickshell` in `environment.persistence."/persist".users.andrew.directories`; the quickshell service unit's `Environment=PATH` (or wrapper) contains `busctl`, `tailscale`, `pkexec`; nixAir additionally `brightnessctl`, `iwctl`. Run → FAIL.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Run tests** + `nixpc-*` + `nixair` groups → PASS (re-pin `nixpc-drv` deliberately, note in ledger).

### Task 4: Terminal (Alacritty, tmux, zsh prompt)

**Files:**
- Create: `home/look/terminal.nix` — from Arch `terminal.nix` with real packages (no `package = null`), colours from `palette.nix`; fonts `jetbrains-mono` + `inter` added (HM `home.packages` + `fonts.fontconfig.enable`, or NixOS `fonts.packages` in `modules/base.nix` — pick one place for both hosts).
- Modify: `home/default.nix` — zsh: keep oh-my-zsh + its plugins (`tmux` autostart etc.), set `theme = ""`, source the generated prompt from `programs.zsh.initContent` (after oh-my-zsh) instead of Arch's manual `.zshrc` line; remove the old `programs.tmux` block and the Snazzy `programs.alacritty`.

- [ ] **Step 1: Tests** (`look_terminal`): generated `~/.config/alacritty/alacritty.toml` text (HM `xdg.configFile."alacritty/alacritty.toml"` source) contains `#c5f36a` and `JetBrains Mono`; tmux config contains `prefix C-a`, `bind t select-pane -D`, `status-left ""`, `#262d1d`; zsh initContent sources `zsh/prompt.zsh` and `programs.zsh.oh-my-zsh.theme == ""`; `jetbrains-mono` and `inter` present for both hosts. Run → FAIL.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Run tests** → PASS.

### Task 5: Shared Hyprland behaviour

**Files:**
- Modify: `home/hyprland.nix` — merge the Mac's behaviour (Arch `hyprland.nix` extraConfig diff vs this file): drop-down terminal `toggle_dropterm` + rule `dropterm`, `dim_special = 0`, fullscreen-keeps-bar handler + `f[1]` workspace/window rules + mainMod+F toggle, hy3 group binds (v/b/w/e/a/Space), mainMod+N `nnn` (add `nnn`), `dex -a -e Hyprland` autostart (add `dex`), launcher = `quickshell ipc -c bar call launcher toggle`, Print/Shift+Print → `quickshell ipc -c bar call tools screenshot region|window`, XF86Audio* → j413 sink lookup with fallback `@DEFAULT_AUDIO_SINK@`, XF86AudioPlay/Next/Prev → `quickshell ipc -c bar call media …`, XF86MonBrightness → `brightnessctl set 10%±` (harmless on nixPC). Remove: `appLauncher`, launcher window rule, old floating-terminal function/rule, `wlsunset` exec, old Print binds. Keep hyprlock on sup+L (no swaylock), keep workstation-only bits.
- Modify: `hosts/nixAir/home.nix` — remove the function-row and media binds now shared; keep monitor (`output = "eDP-1"`, plus a default `preferred/auto/1` rule), touchpad, mainMod+Shift+S screenshot (route through `quickshell ipc -c bar call tools screenshot region`).
- Modify: `hosts/nixAir/default.nix` — `boot.kernelParams = [ "appledrm.show_notch=1" "brcmfmac.feature_disable=0x82000" ]`.

- [ ] **Step 1: Tests** (`look_hyprland`): per host, generated Lua contains `toggle_dropterm`, `special:dropterm`, `"window.fullscreen"`, `workspace = "f[1]"`, `call launcher toggle`, `call tools screenshot region`, `call media playPause`; does not contain `wlsunset`, `swaylock`, `light -`, `floating_terminal_1`, `appLauncher`; **no duplicate binds**: extract every `hl.bind(<key expr>` first argument and assert uniqueness per host; nixAir `boot.kernelParams` contains both params; nixPC's does not. Update the `laptop` group (binds now shared; `brightnessctl`/`playerctl` checks adjusted). Run → FAIL.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Run tests** (`look_hyprland laptop mainmod wallpaper nixair nixpc-baseline nixpc-kernel`) → PASS.

### Task 6: CPU profiles on both hosts

**Files:**
- Create: `modules/cpu-profile.nix` — option `my.cpuProfile.script : path`; installs it as package `cpu-profile`, `systemd.tmpfiles.rules = [ "L+ /usr/local/bin/cpu-profile - - - - <pkg>/bin/cpu-profile" ]`, polkit rule allowing `andrew` to run exactly `/usr/local/bin/cpu-profile` via pkexec without auth (port `50-cpu-profile.rules`, keep its comment about the seat-less manager session).
- Create: `hosts/nixAir/cpu-profile` (the M2 helper, from Arch), `hosts/nixPC/cpu-profile` (new, intel_pstate per Global Constraints: writes `scaling_governor` and `energy_performance_preference` for every `/sys/devices/system/cpu/cpu*/cpufreq`, and `/sys/devices/system/cpu/intel_pstate/no_turbo`; validates its argument like the M2 one).
- Create: `home/look/quickshell/CpuProfileService.qml` — the profile state/`pkexec` logic moved out of `BatteryService.qml` (singleton: `profile`, `pendingProfile`, `profileError`, `profileDetail`, `setProfile(name)`), and `CpuProfileCard.qml` (the profile row UI moved out of `Battery.qml`).
- Modify: `Battery.qml` (uses `CpuProfileCard` when `Host.cpuProfile === "battery"`), `SystemStats.qml` panel (shows it when `"stats"`), `BatteryService.qml` (profile code removed).
- Modify: `hosts/nixAir/default.nix`, `hosts/nixPC/default.nix` — import the module, set the script; `home.nix`s set `my.look.cpuProfile`.

**Interfaces:**
- Consumes: `Host.cpuProfile` (Task 2).
- Produces: `CpuProfileService` singleton API above; `/usr/local/bin/cpu-profile` on both hosts.

- [ ] **Step 1: Tests** (`cpu_profile`): both hosts: tmpfiles rule present, polkit `extraConfig` mentions `/usr/local/bin/cpu-profile` and `andrew`; nixPC script contains `energy_performance_preference` and `no_turbo`, nixAir script contains `policy4`; `shellcheck` both scripts (`nix run --option builders "" nixpkgs#shellcheck`) clean; nixPC script dry-run against a fake sysfs tree (env var `CPU_SYSFS_ROOT`, default `/sys`) sets the three files to the expected values for each profile. Run → FAIL.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Run tests** → PASS.

### Task 7: Wi-Fi on iwd (nixAir)

**Files:**
- Create: `home/look/quickshell/iwd.js` — pure functions: `parseManagedObjects(json) -> { station: {state, connectedNetwork, scanning}, networks: [{path, ssid, security, known, connected, signal}] , known: [{path, ssid}] }` from `busctl --json=short call net.connman.iwd / org.freedesktop.DBus.ObjectManager GetManagedObjects`; `parseOrderedNetworks(json)` (signal per network path from `Station.GetOrderedNetworks`); `signalBars(dbm)`.
- Create: `tests/iwd/{managed-objects.json,ordered-networks.json}` — fixtures captured on nixAir (Andrew runs the two `busctl` commands; until then a hand-written fixture covering: connected PSK network, known-but-absent network, open network, hidden network, 8021x network).
- Create: `tests/iwd/iwd.test.js` — node test of the parser against the fixtures.
- Modify: `home/look/quickshell/WifiService.qml` — backend replaced: poll `GetManagedObjects` + `GetOrderedNetworks` (2–3 s, as now); actions: scan `Station.Scan`, switch/connect known `Network.Connect`, forget `KnownNetwork.Forget`, join new PSK `iwctl --passphrase <pw> station wlan0 connect <ssid>` (passphrase via argv of `iwctl` started by Quickshell — not through a shell), disconnect `Station.Disconnect`, radio via `rfkill`. Keep the properties/signals `Wifi.qml` uses unchanged.
- Modify: `hosts/nixAir/default.nix` — nothing for permissions if `andrew` (wheel) may call iwd over D-Bus; otherwise add the needed group.

- [ ] **Step 1: Tests** (`wifi_iwd`): `nix run --option builders "" nixpkgs#nodejs -- tests/iwd/iwd.test.js` → asserts on all fixture cases; `grep` that no file under `home/look/` mentions `netctl`, `wpa_cli` or `wifi-ctl`; nixAir eval: iwd D-Bus policy (`/etc/dbus-1` from the iwd package) grants `wheel` (or the group `andrew` has). Run → FAIL.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Run tests** → PASS.

### Task 8: Build, switch, look

- [ ] **Step 1:** Full suite → all PASS. Build nixAir locally (`nix build --impure --option builders "" .#nixosConfigurations.nixAir.config.system.build.toplevel`).
- [ ] **Step 2 (Andrew, nixAir):** commit + push (Andrew), `git pull`, `sudo nixos-rebuild switch --flake ~/nixos#nixAir --impure`, reboot (kernel params). Check: notch gap and black fullscreen row, every chip and popup (media, CPU/MEM, volume, Glow incl. brightness, Wi-Fi scan/connect/forget, battery incl. CPU profile switch without password, clock, notifications/DND survive reboot, tools/screenshots, launcher, snowflake menu), drop-down terminal on backtick, terminal colours/prompt/tmux binds. Screenshots compared with the Arch look.
- [ ] **Step 3 (Andrew, nixPC):** `sudo nixos-rebuild boot --flake ~/nixos#nixPC`, reboot. Check: no Wi-Fi/battery chip, no notch gap, Glow temperature only, CPU profiles in the CPU/MEM panel switch without password (`cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference`), Steam still launches.
