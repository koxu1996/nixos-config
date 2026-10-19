# Shared look: Quickshell bar, lime theme, terminal — design

Date: 2026-10-19
Repo: `~/nixos` (gitlab.com/andrzej1_1/nixos-config, `master`), hosts `nixPC` (x86_64 workstation, i7-9700, wired, no battery, no notch) and `nixAir` (MacBook Air M2, Asahi, Wi-Fi via iwd, battery, notch).
Source of the look: the Mac's Arch Home Manager config, `~/.config/home-manager` at commit `47bd856` (read-only for this work; Arch keeps using it until Arch is removed).

## Intent

Andrew built his desktop look on the Mac's Arch install: a Quickshell bar, a lime palette, a themed terminal and refined Hyprland behaviour. The NixOS repo — the single source of truth for both machines — still carries the workstation's older look (waybar, mako, Snazzy Alacritty, old tmux, fixed wlsunset). Move the **whole look and behaviour** into the repo so both NixOS machines look and behave the same, with hardware differences handled per host.

## Goals

1. Both hosts get, from shared Home Manager modules in `home/`:
   - the Quickshell bar (`quickshell/bar` and its config JSON files), started as on Arch (systemd user service via `programs.quickshell`);
   - the lime palette (`theme/palette.nix`) as the one colour source for bar, terminal and prompt;
   - the terminal setup from `terminal.nix`: Alacritty, tmux, zsh prompt;
   - the Mac's Hyprland **behaviour**: drop-down terminal on the backtick key, Quickshell launcher (Super+D on Arch; on NixOS the same physical keys), black top row + borderless/gapless fullscreen, Print/Shift+Print through the bar's tools, media keys through the bar, workspace rules, window rules — everything in the Mac's `hyprland.nix` that isn't Arch- or Mac-hardware-specific.
2. The workstation's old look is removed: waybar, mako, Snazzy Alacritty, old tmux config, the `wlsunset` autostart (replaced by Glow).
3. Per-host differences:

| Feature | nixAir | nixPC |
|---|---|---|
| Wi-Fi chip | yes, **iwd** backend (replaces the Arch netctl/wpa_cli `wifi-ctl` helper) | no (wired) |
| Battery chip/panel (+ charge limit) | yes | no |
| Glow: colour temperature (hyprsunset, schedule/manual) | yes | **yes** (night work) |
| Glow: brightness | yes (laptop backlight) | **no** |
| CPU profiles saver / balanced / performance | yes — existing Apple M2 `cpu-profile` helper, in the battery panel as now | **yes — new helper for the i7-9700** (see below), shown in the bar where it fits without a battery panel (Claude's call: the CPU/MEM panel) |
| Notch gap in the bar (`notchGap` 200 on the notched panel) | yes | no (0) |

4. Both hosts evaluate; nixAir builds locally; nixPC evaluates only on the Mac (no remote builders), Andrew builds/switches on the workstation.

## Non-goals

- Other things in the Mac's Arch HM config that aren't the look: neovim/LazyVim, blender, uv, kitty, opencode, railway, inkscape, etc.
- The hyprlock PAM gap (Andrew: ignore).
- Changing or removing the Arch install / its HM config.
- New features beyond what the Mac has today (except the workstation CPU-profile helper and the iwd Wi-Fi backend, which replace Arch-only pieces).

## Anti-goals

- The workstation losing something it relies on today: Steam/gamescope/gamemode, monero, tpm-fido, printing/scanning, Syncthing, Tailscale, the gpg tools, hy3 tiling, the `pl`/`dvp` layout with `caps:shiflock`, its keycode-based binds working with that layout.
- Silent behaviour differences between the hosts other than the table above.
- Apple firmware or secrets in the (public) repo.
- Any remote/paid build (`--option builders ""` always).

## Constraints and facts

- Quickshell 0.3.0 QML specifics already learned on Arch (singleton pragma placement, PopupWindow anchor margins, HyprlandFocusGrab refused, apps launched through `systemd-run --user --scope`) stay as they are; the QML is ported, not rewritten.
- Config JSON files (`quickshell/launcher/launcher.json`, `glow/profiles.json`, `clock/config.json`) are live-editable on Arch through `mkOutOfStoreSymlink` into the HM repo; on NixOS they point into `~/nixos/...` the same way (`~/nixos` is persisted on nixAir).
- Impermanence: on both hosts only persisted paths survive reboot. Any state the bar keeps (e.g. under `~/.local/state` or `~/.cache`) must be on the persist list if it matters (`.cache` already is).
- Root helpers on Arch live in `/usr/local/bin` with polkit rules; on NixOS they become packages + polkit rules in NixOS modules (the bar may keep calling a fixed path, e.g. via `systemd.tmpfiles` `L+ /usr/local/bin/...`, as `quickshell/battery/README.md` sketches).
- Arch-specific bits in the Mac's `hyprland.nix` need NixOS equivalents or removal: `portalPackage = null` (NixOS portal is configured in `modules/base.nix`), swaylock with Arch PAM → hyprlock (as the repo has now), `light` → `brightnessctl`, Arch's tbsm whitelist file, `mako.service` → /dev/null masking, comments mentioning xremap (Cmd/Option are now swapped by `hid_apple swap_opt_cmd=1` on nixAir).
- The Mac's media-key binds look up the `audio_effect.j413-convolver` sink by name (Asahi DSP). On nixAir check the sink name exists under NixOS's Asahi sound setup; nixPC uses the default sink.
- nixAir-only Hyprland bits already in `hosts/nixAir/home.nix` (monitor scale 2, touchpad, function-row binds, region screenshot on mainMod+Shift+S because there's no Print key) stay nixAir-only and must not conflict with the shared binds.
- Workstation CPU profiles (i7-9700, Coffee Lake, intel_pstate with HWP): Claude's call for the three profiles —
  - saver: governor `powersave`, EPP `power`, turbo off;
  - balanced: governor `powersave`, EPP `balance_performance`, turbo on;
  - performance: governor `performance`, EPP `performance`, turbo on.
  Same command interface as the M2 helper (`cpu-profile saver|balanced|performance`) so the bar code differs only in where it's shown.

## Calls settled after the builder check (Claude's calls unless marked)

- **Source snapshot:** the look on Arch is only partly committed in `~/.config/home-manager` (quickshell/, theme/, terminal.nix, hyprland.nix are intent-to-add). Port from the **live working tree at the start of implementation**; Andrew doesn't change the Arch look meanwhile. Record the copied tree's file list + a hash in the first commit message.
- **nixAir function-row keys:** the Mac's behaviour wins ("behaviour the same"): play/next/previous through `quickshell ipc … media`, volume/mute through the Asahi DSP sink (`audio_effect.j413-convolver`, looked up by name, falling back to `@DEFAULT_AUDIO_SINK@` if absent on NixOS), brightness through `brightnessctl` (replacing Arch's `light`). The existing nixAir binds in `hosts/nixAir/home.nix` for these keys are replaced, not duplicated; the mainMod+Shift+S region screenshot stays (no Print key). `tests/check.sh` laptop checks are updated accordingly.
- **nixAir kernel parameters:** add `appledrm.show_notch=1` (Andrew enabled the real notch on Arch; without it the panel is 1280×800 and the notch gap never applies) and Arch's `brcmfmac.feature_disable=0x82000` (the Wi-Fi quirk Arch boots with).

- **nixPC waybar extras (Andrew):** the `custom/voice` widget is no longer needed — dropped. The system tray is dropped too (Andrew already chose "no need for tray" when the Mac moved from waybar to Quickshell).
- **Glow schedule (Andrew):** one shared `glow/profiles.json` for both hosts — the Mac's (Warsaw 52.23, 21.01; 6500/4000/2700 K). The workstation's old wlsunset values (55.7:12.6, 5600/3600 K) were wrong and go away.

## Architecture (builder may adjust names)

- `home/look/` (or similar): `quickshell/` (copied tree), `theme/palette.nix`, `terminal.nix`, the shared Hyprland behaviour merged into `home/hyprland.nix`.
- Per-host bar features through Home Manager options (e.g. `my.bar.wifi`, `my.bar.battery`, `my.bar.glowBrightness`, `my.bar.notchGap`, `my.bar.cpuProfileIn = "battery" | "stats"`), rendered into a small generated QML/JSON settings file the bar reads — no `if hostname`.
- Root helpers (`cpu-profile` per CPU, nothing for Wi-Fi if iwd's D-Bus/`iwctl` works for the user) as NixOS modules under `modules/` or `hosts/<name>/`.

## Verification

- `tests/check.sh` gains checks: both hosts have `programs.quickshell` enabled and no waybar/mako; the per-host feature flags match the table; nixPC still has steam/monero/tpm; palette colours appear in the generated Alacritty and tmux configs; nixAir's notch gap 200, nixPC 0.
- Existing checks stay green (adjusting the nixPC baseline drvPath deliberately).
- nixAir: `nixos-rebuild switch` by Andrew, then a visual check against the Arch look (screenshot comparison welcome) and a walk through each chip/popup.
- nixPC: eval + Andrew's build/switch on the workstation.

## Left to the builder

- Exact file layout, option names, how bar flags reach QML.
- How the iwd backend talks to iwd (D-Bus vs `iwctl`) — must not need root for scan/connect as `andrew` (iwd's D-Bus policy allows the `wheel`/`netdev` group or similar; verify).
- Whether Glow's brightness UI is hidden or removed on nixPC.
- Commit granularity (commits only when Andrew asks; never push — Andrew pushes).
