#!/usr/bin/env bash
# idle-check.sh: does the bar stop drawing when nothing changes?
#
#   dev/idle-check.sh [seconds]   Count frames the running bar renders (its QSGRenderThread
#                                 wakeups). Read-only. Run with hands off the laptop.
#   dev/idle-check.sh --animations
#                                 Start a copy of the deployed bar with every infinite
#                                 animation logging its running state, for ~15 s, with the
#                                 real bar paused, and list the ones still running at the end.
#
# Why: an animation keeps running while its item is in a hidden popup, and Qt advances it
# through the visible bar's render loop, so the bar (and Hyprland compositing it) draws
# 60 identical frames a second. Seen twice: the Syncthing spinner stuck on offline peers,
# and the Wi-Fi connect-step pulse while connected (~5% CPU each for bar and Hyprland).
set -euo pipefail

bar_pid() { systemctl --user show quickshell -p MainPID --value; }

if [ "${1:-}" != "--animations" ]; then
    secs=${1:-10}
    pid=$(bar_pid)
    rt=$(grep -l '^QSGRenderThread$' /proc/"$pid"/task/*/comm | head -1 | sed 's/comm$/status/')
    wake() { awk '/^voluntary/{print $2}' "$rt"; }
    cpu() { awk '{print $14+$15}' /proc/"$pid"/stat; }
    pos1=$(hyprctl cursorpos); w1=$(wake); c1=$(cpu)
    sleep "$secs"
    pos2=$(hyprctl cursorpos); w2=$(wake); c2=$(cpu)
    fps=$(( (w2 - w1) / secs ))
    echo "bar: ~${fps} frames/s, $(awk -v c=$((c2 - c1)) -v s="$secs" 'BEGIN{printf "%.1f", c/s}')% CPU over ${secs}s"
    [ "$pos1" != "$pos2" ] && { echo "cursor moved: input causes frames too, rerun with hands off"; exit 2; }
    # Idle budget: per-second stats and the clock are a few frames; anything near 60 is an animation.
    [ "$fps" -le 5 ] && echo "OK: idle" || {
        echo "FAIL: the bar keeps rendering. --animations finds infinite animations; short bursts"
        echo "      (e.g. a poll re-running a Repeater) need qmlprofiler on a copy (see CLAUDE.md)."
        exit 1; }
    exit 0
fi

QS=$(readlink -f "$(command -v quickshell)")
copy=$(mktemp -d)
cp -rL "$(readlink -f ~/.config/quickshell/bar)/." "$copy"
chmod -R u+w "$copy"
# A second bar must not touch hyprsunset or the backlight (it would reset Glow).
sed -i -e 's|Quickshell.execDetached(\["sh", "-c", command + " >/dev/null"\]);|/* glow off in copy */|' \
       -e 's|onTriggered: Quickshell.execDetached(\["brightnessctl".*$|onTriggered: {}|' \
       "$copy/GlowService.qml"
if grep -q execDetached "$copy/GlowService.qml"; then
    echo "GlowService.qml changed: update the sed lines above before running a copy" >&2
    exit 1
fi
# Log every infinite animation's state: "ANIM file:line start=<bool>" once per instance, then
# "ANIM file:line change=<bool>". The change handler is skipped where the animation already has
# an onRunningChanged (QML allows one); start=true is still logged there.
for f in "$copy"/*.qml; do
    grep -q 'loops: Animation.Infinite' "$f" || continue
    awk -v F="$(basename "$f")" '
        { line[NR] = $0 }
        END {
            for (i = 1; i <= NR; i++) {
                print line[i]
                if (line[i] !~ /loops: Animation.Infinite/) continue
                match(line[i], /^ */); ind = substr(line[i], 1, RLENGTH)
                own = 0
                for (j = i + 1; j <= NR && line[j] !~ /^ *}/; j++) if (line[j] ~ /onRunningChanged/) own = 1
                print ind "Component.onCompleted: console.warn(\"ANIM " F ":" i " start=\" + running)"
                if (!own) print ind "onRunningChanged: console.warn(\"ANIM " F ":" i " change=\" + running)"
            }
        }' "$f" >"$f.new"
    mv "$f.new" "$f"
done

real=$(bar_pid)
log=$(mktemp)
cleanup() {
    # Wait for the copy to exit: it writes its state dir while shutting down.
    [ -n "${cpid:-}" ] && { kill "$cpid" 2>/dev/null; wait "$cpid" 2>/dev/null; } || true
    kill -CONT "$real" 2>/dev/null || true
    id=$(sed -n 's/.*Shell ID: "\([0-9a-f]*\)".*/\1/p' "$log" | head -1)
    [ -n "$id" ] && rm -rf ~/.local/state/quickshell/by-shell/"$id"
    rm -rf "$copy" "$log"
}
trap cleanup EXIT
kill -STOP "$real"
"$QS" -p "$copy" >"$log" 2>&1 &
cpid=$!
sleep 15
sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -E 'ERROR' && { echo "copy failed to load" >&2; exit 1; }
# Running instances per site: +1 for start=true or change=true, -1 for change=false.
sed 's/\x1b\[[0-9;]*m//g' "$log" | sed -n 's/.*ANIM \([^ ]*\) \(start\|change\)=\(.*\)/\1 \2 \3/p' |
    awk '$3 == "true" { on[$1]++ } $2 == "change" && $3 == "false" { on[$1]-- }
        END { bad = 0
              for (k in on) if (on[k] > 0) { print "still running: " k " (" on[k] " instance(s))"; bad = 1 }
              if (!bad) print "OK: no infinite animation left running"
              exit bad }'
