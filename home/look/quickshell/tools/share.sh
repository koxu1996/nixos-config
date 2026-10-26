#!/usr/bin/env bash
# share.sh: the Tools menu's Share (ToolsService.qml), like Omarchy's: hands paths to
# LocalSend, which opens on its Send tab with them selected (a running LocalSend gets them).
#   clipboard  copied files as themselves, an image as an image file, anything else as .txt
#   file       pick files      folder  pick a folder      receive  just open LocalSend
# Clipboard copies go to $XDG_RUNTIME_DIR (gone at logout), so LocalSend can still read them.
set -euo pipefail

fail() {
    notify-send -a Share -u critical "Share failed" "$1" || true
    exit 1
}

paths=()
case ${1:-} in
clipboard)
    types=$(wl-paste --list-types 2>/dev/null) || fail "The clipboard is empty."
    image=$(grep -m1 '^image/' <<<"$types" || true)
    if grep -qx 'text/uri-list' <<<"$types"; then
        # Files copied in a file manager: file:// URIs, percent-encoded.
        while IFS= read -r uri; do
            uri=${uri%$'\r'}
            [[ $uri == file://* ]] || continue
            path=${uri#file://}
            paths+=("$(printf '%b' "${path//%/\\x}")")
        done < <(wl-paste --type text/uri-list)
        ((${#paths[@]})) || fail "The copied items aren't local files."
    elif [ -n "$image" ]; then
        out="$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/share-XXXXXX")/clipboard.${image#image/}"
        wl-paste --type "$image" >"$out"
        paths=("$out")
    else
        out="$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/share-XXXXXX")/clipboard.txt"
        wl-paste --no-newline >"$out"
        paths=("$out")
    fi
    ;;
file)
    # Cancel: exit quietly.
    picked=$(zenity --file-selection --multiple --separator=$'\n' --title "Share files") || exit 0
    mapfile -t paths <<<"$picked"
    ;;
folder)
    picked=$(zenity --file-selection --directory --title "Share a folder") || exit 0
    paths=("$picked")
    ;;
receive) ;;
*)
    echo "usage: share.sh clipboard|file|folder|receive" >&2
    exit 2
    ;;
esac

# Its own transient unit: LocalSend outlives this script and the bar.
exec systemd-run --user --quiet --collect localsend_app "${paths[@]}"
