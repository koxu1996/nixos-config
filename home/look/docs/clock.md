# Clock

Bar clock with a popup (big time, date, ISO week, month calendar, extra time zones).
Lives in the Quickshell bar (`home/look/quickshell`): `ClockService.qml` (shared time, date
helpers, zone lookups), `ClockChip.qml` (bar chip), `ClockPopup.qml`, `MonthCalendar.qml`,
`ZoneList.qml`. Styling comes from `Theme.qml`.

## Placing the chip in the bar

`ClockChip {}` is self-contained: it shows `21:59 · Wed 14 Oct`, and a click toggles the
popup (opens under the chip, right-aligned; Escape or a click outside closes it). In
`shell.qml` it sits in the right-end row, between the Tools and notification chips:

```qml
Row {
    // ... Media, SystemStats, Volume, GlowButton, Wi-Fi, Battery
    ToolsChip {}
    ClockChip {}
    NotificationChip {}
}
```

`ClockService` is a singleton: other components can use
`ClockService.now`, `.timeText`, `.shortDate`, `.isoWeek(date)` or `.monthGrid(y, m)`.

## Time zones: `~/.config/quickshell/clock/config.json`

A symlink to `home/look/quickshell/clock-config.json` in this repo (set up in
`quickshell.nix`); edits apply live.

```json
[
  { "name": "UTC", "tz": "UTC" },
  { "name": "New York", "tz": "America/New_York" }
]
```

`tz` is an IANA zone name (a file under `/usr/share/zoneinfo`); unknown zones show
`--:--` and "unknown zone". With no zones the list is hidden.

## How it works

- Time: Quickshell `SystemClock`, minute precision, seconds only while the popup is open.
- English names, 24-hour time, weeks start on Monday, ISO 8601 week numbers, leap years.
- The calendar always has 42 cells (6 weeks), so the popup never changes height.
- Zone times: QML's JS engine ignores `toLocaleString`'s `timeZone` option and has no
  `Intl`, so each minute one `sh` process runs `TZ=<zone> date "+%z %H:%M"` for every
  zone (plus the local offset). That is correct across DST; offsets are shown relative
  to local time (`same`, `+3h`, `−6h`, `+3:30h`).
