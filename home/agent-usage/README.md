# agent-usage

Omarchy's **Agents** panel (`shell/plugins/agents`, from
[basecamp/omarchy](https://github.com/basecamp/omarchy) `quattro`, MIT — see
`LICENSE`) running in this repo's own Quickshell bar, plus an **OpenCode Zen**
balance collector. Upstream's own documentation of the record contract, the
accounts registry and sync is `shell/plugins/agents/README.md`; this file
covers how it lives here.

## Layout

| Path | What |
|---|---|
| `bin/`, `shell/`, `default/i18n/en/`, `LICENSE` | Upstream copies, byte-for-byte. `UPSTREAM` names the commit and lists every copied file. |
| files whose header says `LOCAL` | Ours: `bin/omarchy-agent-usage-opencode`, `bin/omarchy-i18n` (English only), the shims (`omarchy-notification-send` → notify-send, `omarchy-launch-browser` → xdg-open / a private window, `omarchy-launch-tui` and `…-floating-terminal-with-presentation` → `$TERMINAL -e`, `omarchy-mise-*` → "comes from Nix"), `shell/Commons/I18n.qml` (English only), `assets/opencode.svg` |
| `patches/` | Applied to that tree at build time: 0001 CLIs come from Nix, not mise · 0002 theme from this module · 0003 OpenCode Zen in the manifest defaults · 0004 `qmldir`s list only what's vendored · 0005 `account copy` receiver paths that exist on NixOS |
| `default.nix` | The home-manager module `programs.agent-usage` |
| `../look/quickshell/AgentsChip.qml` | The bar's side: plays Omarchy's bar for the plugin (`PluginBarApi`), feeds it settings, joins `PopupManager` |

The built tree is `OMARCHY_PATH`. Every `omarchy-*` command is on PATH as a
wrapper that sets `OMARCHY_PATH`, `$TERMINAL` and the scripts' tools (python3,
jq, libnotify, xdg-utils, gum…). The QML (`Commons/`, `Ui/`, `plugins/agents/`)
is merged into the bar's config root (`~/.config/quickshell/bar`), not a
separate `~/.config/quickshell/agent-usage/`: `import qs.Commons` resolves
against the shell root, so it has to sit there.

## Config files

| File | Owner | What |
|---|---|---|
| `~/.config/agent-usage/settings.json` | module (read-only) | The plugin's settings: `providers.<id>.enabled`, `refreshIntervalSec`, `syncMode`, `syncDir`, `syncFileName`, `syncDeviceId`. Overlaid on `manifest.json`'s defaults; the bar watches it. |
| `~/.config/agent-usage/theme/{colors,shell}.toml` | module | The palette, font, radius, spacing and motion behind `Color`/`Style` (`programs.agent-usage.theme.*`, defaults = the bar's `Theme.qml`). |
| `~/.config/omarchy/agents/opencode.json` | you | Zen funding. A symlink to `<syncDir>/opencode-funding.json`, so every machine shares one list. |
| `~/.config/omarchy/defaults/agent` | module writes it once | The agent the panel's start button and a right-click on the chip launch (`claude`). |
| `~/.local/state/omarchy/agents/` | the scripts | `usage/<id>.json` records, `accounts/` (registry + added accounts' homes), `order.json`. Persisted (`modules/persist.nix`, 0700). |
| `<syncDir>/<hostname>.json`, `<syncDir>/opencode-spend/<hostname>.json` | each machine | Synced snapshots: local stats only, never limits or tokens; and the machine's daily Zen spend. |

Records regenerate from the panel's own timer, on open, on middle-click or `r`,
and from the `agent-usage-update` systemd user timer (every
`refreshIntervalSec`), which keeps them fresh while the bar is down.

## I topped up Zen

Append the top-up to the funding list, with the credit amount (not what the
card was charged) and the day it landed:

```json
{
  "funding": [
    { "usd": 20, "at": "2026-10-01" },
    { "usd": 20, "at": "2026-10-19" }
  ]
}
```

`$EDITOR ~/.config/omarchy/agents/opencode.json` — it is the synced
`~/Sync/agent-usage/opencode-funding.json`, so do it on one machine. The
balance is Σ`usd` − every machine's Zen cost since the earliest `at`, from the
`cost` OpenCode stores per response; it updates on the next refresh (`r` in the
panel). Zen reloads $20 on its own under $5; if the estimate falls below −$1 the
panel says *Zen reload likely*, which means a funding entry is missing — check
the console's billing history and add it. Start the list with the console's
current balance and today's date if older history isn't at hand.

## Add an account

```bash
omarchy-agent-account-add claude Work      # or the panel's + → Claude Code → name → Enter
```

The first Claude login stays in `~/.claude` (account *Main*). The new one signs
in through a private browser window into
`~/.local/state/omarchy/agents/accounts/claude/work/`, which holds only its own
`.credentials.json` / `.claude.json`; everything else (projects, settings,
skills, history…) is a link back to `~/.claude`.

- Switch: the account's **Use** in the panel, or `omarchy-agent-account-use claude work` (`main` to go back). Running sessions keep their account; new ones start as the active one.
- `claude` in a shell is a function that runs through `omarchy-agent-account-exec claude`, so it gets the active account's `CLAUDE_CONFIG_DIR` (empty for Main). `echo $CLAUDE_CONFIG_DIR` from inside a session shows which.
- `omarchy-agent-account-list`, `…-rename claude work Day-job`, `…-remove claude work`.
- Already signed in to the second account on another machine: `omarchy-agent-account-copy <ssh-host> claude` copies the logins there (over SSH, stdin only), or `omarchy-agent-account-transfer export claude | ssh host omarchy-agent-account-transfer import`.
- Switch mode is `manual`: crossing the threshold (95%) only notifies. The autoswitch code and the panel's Autoswitch control are upstream's and still there, off by default; they're not set up or tested here.

## Set up sync on a second machine

1. Share the Syncthing folder `~/Sync` with the machine (web UI, `127.0.0.1:8384`).
2. Its home config gets the same `programs.agent-usage = { enable = true; syncDir = "~/Sync/agent-usage"; syncthingFolder = "~/Sync"; };` — `home/default.nix` already does that for every host.
3. Rebuild. It writes `~/Sync/agent-usage/<hostname>.json` (from `/etc/hostname`, i.e. `networking.hostName`; `syncDeviceId`/`syncFileName` override it), and the panel footer reads *Merged from 2 devices*. Each machine writes only its own file, so Syncthing normally has nothing to conflict over; `syncthingFolder` adds `.stignore` patterns for the writers' split-second temp files. If a conflict copy (`nixAir.sync-conflict-….json`) or a renamed file still turns up, the bar and the Zen spend merge keep only the newest snapshot per `deviceId` (patch 0006), so no machine is counted twice; the stale copy can simply be deleted.
4. Second Claude account there: add it again, or `omarchy-agent-account-copy` it from here (above).

Limits and balances are never merged: each machine probes its own accounts.
The Zen balance is the exception that needs the other machines — their spend
comes from `opencode-spend/`.

## Rebase on upstream

```bash
git clone -b quattro https://github.com/basecamp/omarchy /tmp/omarchy
home/agent-usage/update-upstream.sh /tmp/omarchy
git diff home/agent-usage              # what changed upstream
```

The script re-copies every file in `UPSTREAM`, records the new commit, lists
new upstream agent scripts or plugin files, and dry-runs each patch. A patch
that no longer applies: edit a copy of the tree, `diff -u` it back into
`patches/` (paths `a/…`/`b/…`, `patch -p1`). If `Panel.qml` gains a new
`qs.Ui`/`qs.Commons` import, copy that file in, add it to `UPSTREAM`, and keep
`0004`'s `qmldir`s in step. Then `nixos-rebuild switch` and open the panel.

## Known differences from Omarchy

- The panel is a full-screen overlay while open (upstream `KeyboardPanel`): a click on another bar chip closes it first.
- With several monitors every bar's chip runs its own refresher; harmless (the scripts lock), just repeated work.
- No settings UI: change `programs.agent-usage.*` and rebuild.
- Codex, Grok, Fireworks and Kimi collectors are vendored but disabled (`providers.<id>.enable`).
