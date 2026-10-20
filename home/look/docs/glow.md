# Glow

Screen colour temperature (through hyprsunset) and backlight brightness for Hyprland.
Lives in the Quickshell bar (`home/look/quickshell`): `GlowService.qml` (state, schedule,
IPC, sunset maths), `Glow.qml` (popup), `GlowButton.qml` (bar chip),
`ModeSelector.qml`, `ProfileCard.qml`, `GlowSlider.qml`. Styling comes from `Theme.qml`.

## Opening it from a bar button

`GlowButton {}` is a ready-made chip (light colour + temperature, or "off"); a left
click toggles the popup. For your own button, host the popup next to it:

```qml
Glow { id: glow; anchorItem: myButton }   // popup opens under myButton, right-aligned
MouseArea { anchors.fill: myButton; onClicked: glow.toggle() }
```

`GlowService` is a singleton, so any other component can read `GlowService.temperature`,
`.brightness`, `.mode` or `.subtitle`, or call `GlowService.setMode("manual")` and
`GlowService.resetManual()`.

## Config: `~/.config/quickshell/glow/profiles.json`

A symlink to `home/look/quickshell/glow-profiles.json` in this repo (set up in
`quickshell.nix`), so edits apply live (the file is watched) and stay in git. Profiles are read-only in the UI.

```json
{
  "latitude": 52.23,
  "longitude": 21.01,
  "profiles": [
    { "name": "Day", "time": "07:00", "temperature": 6500 },
    { "name": "Evening", "time": "sunset", "temperature": 4000 },
    { "name": "Night", "time": "22:30", "temperature": 2700 }
  ]
}
```

- `time`: `"HH:MM"` or `"sunset"`, computed locally each day from `latitude`/`longitude`
  (NOAA formula, no network). Sunset profiles are skipped without a location.
- `temperature`: K, clamped to 1000–10000. Profiles are colour only: the schedule never
  changes brightness (any `brightness` field is ignored).
- The active profile is the latest one that has started today; before the first one,
  yesterday's last one stays active.

## Layout, modes and state

The popup has two independent parts:

- **Brightness** (top): the panel backlight, in both modes, shown only on hosts with
  `my.look.glowBrightness` (`Host.glowBrightness`). The slider shows the real level (read
  with `brightnessctl -m` every second while the popup is open, so the brightness keys
  show up) and sets it with `brightnessctl set N%` when you move it. 0–100 %; at 0 the backlight
  may switch off entirely.
- **Color**: a Schedule / Manual switch for the colour temperature only.

- **Schedule** applies the active profile's temperature (re-checked every minute).
- **Manual** applies the temperature slider live and overrides the schedule until you
  switch back. Switching from Schedule starts at the active profile's temperature (or
  original colours when no profile is active), so the switch itself changes nothing.
  **Reset** restores original colours (hyprsunset `identity`, not a 6500 K tint) and
  leaves brightness alone; moving the temperature slider tints again. Manual + Reset is
  how to turn the tint off.

Brightness is never scheduled and never re-applied, so the brightness keys always work.

The colour mode and manual temperature persist in Quickshell's state dir
(`~/.local/state/quickshell/by-shell/<id>/glow.json`).

## Backend

hyprsunset runs as a Home Manager user service (`services.hyprsunset` in
`quickshell.nix`) with no profiles of its own and `--identity`, so it starts neutral and
Glow owns the schedule. Glow drives it with `hyprctl hyprsunset temperature|identity` (50 ms
debounce) and keeps hyprsunset's gamma at 100: on the MacBook (nixAir, Asahi), Apple's display coprocessor applies
the colour matrix's tint but ignores its overall scale, so hyprsunset gamma cannot dim
the screen. In hyprsunset, setting a temperature also turns identity off. Even 6500 K is not identity (hyprsunset still trims ~2% blue);
only Disabled gives the untouched original colours.
