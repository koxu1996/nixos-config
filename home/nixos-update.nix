# nixos-update — pull ~/nixos and switch this machine to it; the snowflake menu's
# "Update system" runs it in a terminal (home/look/quickshell/SystemMenu.qml).
#
# Local changes (the per-host password line in modules/base.nix) are stashed around the
# pull and put back before the build, so they still end up in the system. The flake output
# is this machine's hostname (nixAir / nixPC), baked in at build time.
{ osConfig, pkgs, ... }:

let
  nixos-update = pkgs.writeShellApplication {
    name = "nixos-update";
    runtimeInputs = [ pkgs.git pkgs.nix-output-monitor ];
    # sudo and nixos-rebuild come from the system PATH.
    text = ''
      repo="$HOME/nixos"
      host="${osConfig.networking.hostName}"

      step() { printf '\n\033[1;32m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
      finish() {
        printf '\n%b\n' "$1"
        read -rp "Press Enter to close" _ || true
        exit "$2"
      }
      fail() { finish "\033[1;31m✗ $*\033[0m" 1; }

      cd "$repo"

      stashed=0
      if ! git diff --quiet || ! git diff --cached --quiet; then
        step "Stashing local changes"
        git status --short --untracked-files=no
        git stash push -m "nixos-update $(date -Is)" || fail "Couldn't stash local changes."
        stashed=1
      fi

      step "Pulling $(git remote get-url origin)"
      pulled=1
      git pull --ff-only || pulled=0

      if [ "$stashed" = 1 ]; then
        step "Restoring local changes"
        git stash pop || fail "Restoring local changes conflicted; they are still in \`git stash list\`."
      fi
      [ "$pulled" = 1 ] || fail "Pull failed (local commits not on GitLab?); nothing rebuilt."

      step "Rebuilding $host ($(git log -1 --format='%h %s'))"
      sudo -v || fail "sudo failed; nothing rebuilt."
      # nom: live build progress from nix's JSON log.
      sudo nixos-rebuild switch --flake "$repo#$host" --impure --log-format internal-json -v |& nom --json \
        || fail "Rebuild failed; the running system is unchanged."

      finish "\033[1;32m✓ $host is up to date.\033[0m" 0
    '';
  };
in
{
  home.packages = [ nixos-update ];
}
