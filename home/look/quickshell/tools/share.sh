#!/usr/bin/env bash
# share.sh: the Tools menu's Share (ToolsService.qml), like Omarchy's: hands paths to
# LocalSend, which opens on its Send tab with them selected (a running LocalSend gets them).
#   clipboard  copied files as themselves, an image as an image file, anything else as .txt
#   file       pick files      folder  pick a folder      receive  just open LocalSend
# Picking is yazi in the floating file-chooser terminal (home/yazi.nix): Enter picks (Space
# marks several); for a folder, go into it and press q, or mark it and press Enter.
# Clipboard copies go to $XDG_RUNTIME_DIR (gone at logout), so LocalSend can still read them.
set -euo pipefail

fail() {
    notify-send -a Share -u critical "Share failed" "$1" || true
    exit 1
}

# choose <title> [cwd file]: yazi's picks, one per line, in $chosen (empty: nothing picked).
chosen=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/share-pick-XXXXXX")
trap 'rm -f "$chosen" "$chosen.cwd"' EXIT
choose() {
    alacritty --class filechooser --title "$1" -e yazi --chooser-file="$chosen" ${2:+--cwd-file="$chosen.cwd"} "$HOME" || true
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
    choose "Share files"
    # Cancel (q without picking): exit quietly.
    [ -s "$chosen" ] || exit 0
    mapfile -t paths <"$chosen"
    ;;
folder)
    choose "Share a folder" cwd
    if [ -s "$chosen" ]; then
        mapfile -t paths <"$chosen"
    elif [ -s "$chosen.cwd" ] && [ "$(cat "$chosen.cwd")" != "$HOME" ]; then
        # Quit inside the folder. Quitting in ~ itself counts as cancel.
        paths=("$(cat "$chosen.cwd")")
    else
        exit 0
    fi
    ;;
receive) ;;
*)
    echo "usage: share.sh clipboard|file|folder|receive" >&2
    exit 2
    ;;
esac

# Its own transient unit: LocalSend outlives this script and the bar. (exec skips the trap.)
rm -f "$chosen" "$chosen.cwd"
exec systemd-run --user --quiet --collect localsend_app "${paths[@]}"
