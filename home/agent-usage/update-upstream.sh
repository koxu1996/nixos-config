#!/usr/bin/env bash
# Re-copy every upstream file listed in UPSTREAM from an Omarchy checkout, record its
# commit, and check that patches/ still applies. Review the result with `git diff`.
#
#   git clone -b quattro https://github.com/basecamp/omarchy /tmp/omarchy
#   home/agent-usage/update-upstream.sh /tmp/omarchy
set -euo pipefail

src=${1:?usage: update-upstream.sh <omarchy checkout>}
here=$(cd "$(dirname "$0")" && pwd)
cd "$here"

rev=$(git -C "$src" rev-parse HEAD)
branch=$(git -C "$src" rev-parse --abbrev-ref HEAD)

missing=0
while read -r path; do
  [[ -z $path || $path == \#* ]] && continue
  if [[ -f $src/$path ]]; then
    cp "$src/$path" "$path"
  else
    echo "gone upstream: $path" >&2
    missing=1
  fi
done < <(tail -n +2 UPSTREAM)

sed -i "1s|.*|$rev $branch https://github.com/basecamp/omarchy|" UPSTREAM

# New agent scripts or plugin files upstream (Commons/ and Ui/ are pruned on purpose:
# add a file there only when a new import needs it).
comm -13 <(ls bin shell/plugins/agents | sort)   <({ ls "$src/bin" | grep '^omarchy-agent'; ls "$src/shell/plugins/agents"; } | sort) |
  grep -v '^$' | sed 's|^|new upstream: |' >&2 || true

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -r bin shell default "$tmp"/
for patch in patches/*.patch; do
  if patch -d "$tmp" -p1 --forward --silent <"$patch"; then
    echo "applies: $patch"
  else
    echo "FAILS:   $patch (rebase it against the new copies)" >&2
    missing=1
  fi
done
exit $missing
