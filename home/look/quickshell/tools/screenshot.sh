#!/usr/bin/env bash
# screenshot.sh: captures for the bar's Tools menu (ToolsService.qml) and the Print keys.
#   region  pick an area, or click a window on this workspace
#           -> $XDG_RUNTIME_DIR/shot-latest.png, copied to the clipboard
#   window  the active window -> /tmp/shot-YYYYmmdd-HHMMSS.png, with Open / Copy path actions
# Hyprland reports logical (layout) coordinates, which is also what grim -g takes, so the
# 2x internal display needs no scaling here.
set -euo pipefail

fail() {
    notify-send -a Screenshot -u critical "Screenshot failed" "$1" || true
    exit 1
}

case ${1:-} in
region)
    out="${XDG_RUNTIME_DIR:-/tmp}/shot-latest.png"
    ws=$(hyprctl -j activeworkspace | jq -r '.id')
    # Visible windows on this workspace as slurp boxes ("x,y wxh"), clickable as targets.
    boxes=$(hyprctl -j clients | jq -r --argjson ws "$ws" \
        '.[] | select(.workspace.id == $ws and .mapped and (.hidden | not))
             | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
    # Escape in slurp: exit quietly.
    geom=$(if [ -n "$boxes" ]; then printf '%s\n' "$boxes"; fi | slurp -d -b '#07080b9e' -c '#c5f36aff' -s '#00000000' -w 1 \
        -F 'JetBrains Mono') || exit 0
    [ -n "$geom" ] || exit 0
    grim -g "$geom" "$out" || fail "grim could not capture $geom"
    wl-copy --type image/png < "$out"
    size=${geom#* }
    notify-send -a Screenshot -i "$out" "Copied to clipboard" "${size%x*}×${size#*x} · region"
    ;;
window)
    geom=$(hyprctl -j activewindow | jq -r 'if .at then "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])" else empty end')
    [ -n "$geom" ] || fail "No active window"
    out="/tmp/shot-$(date +%Y%m%d-%H%M%S).png"
    grim -g "$geom" "$out" || fail "grim could not capture $geom"
    # notify-send prints the chosen action (nothing if dismissed).
    choice=$(notify-send -a Screenshot -i "$out" -A open=Open -A copy="Copy path" \
        "Screenshot saved" "$out" || true)
    case $choice in
    # Own scope: the viewer must not live in (and die with) the bar's cgroup.
    open) systemd-run --user --scope --quiet --collect -- xdg-open "$out" >/dev/null 2>&1 & ;;
    copy) printf %s "$out" | wl-copy ;;
    esac
    ;;
*)
    echo "usage: screenshot.sh region|window" >&2
    exit 2
    ;;
esac
