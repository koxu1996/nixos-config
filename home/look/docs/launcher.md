# App launcher

`Launcher.qml` (window), `LauncherSearch.qml`, `PinnedRow.qml`, `CommandRow.qml` and
`LauncherService.qml` (data, fuzzy matching, launching) in `home/look/quickshell`. It is created
once in `shell.qml` and opened on the focused screen with **Super+D**
(`quickshell ipc -c bar call launcher toggle`, bound in `hyprland.nix`).

## Pinned apps

Pinned apps are listed in `home/look/quickshell/launcher.json`, which Home Manager links to
`~/.config/quickshell/launcher/launcher.json` (set up in `quickshell.nix`):

```json
{ "pinned": ["brave", "keepassxc"] }
```

- Each entry is a desktop-entry id (the `.desktop` file name without `.desktop`, e.g.
  `org.keepassxc.KeePassXC`) or something close to it (`keepassxc`, `brave`, or the command it runs, like `obs`): an exact id
  is tried first, then Quickshell's heuristic lookup. The desktop entry supplies the name,
  the icon and how the app is started.
- If no desktop entry matches, the entry is shown as a plain command with a terminal glyph
  and run through `bash -lc`.
- Order in the file is the order in the launcher. Pinned ids are left out of the command list.
- Edits apply immediately (the file is watched); no rebuild needed. There is no pin/unpin in
  the UI.

To find ids: `ls /usr/share/applications ~/.nix-profile/share/applications ~/.local/share/applications`.

## Keys

↑/↓, Tab/Shift+Tab, Ctrl+N/Ctrl+K select; Enter launches; Esc or a click on the dimmed
background closes. When nothing matches, Enter runs the typed text in a shell.
