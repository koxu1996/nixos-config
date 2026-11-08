# nixos-update — pull ~/nixos and switch this machine to it; the snowflake menu's
# "Update system" runs it in a terminal (home/look/quickshell/SystemMenu.qml).
#
# Local changes stay in the working tree and end up in the system (git refuses the pull
# only if they touch files it changes). The flake output is this machine's hostname
# (nixAir / nixPC), baked in at build time.
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

      step "Pulling $(git remote get-url origin)"
      git pull --ff-only \
        || fail "Pull failed (diverged from origin, or local changes in the files it updates); nothing rebuilt."

      step "Rebuilding $host ($(git log -1 --format='%h %s'))"
      # --sudo: builds as andrew, sudo only for the activation (it asks for the password then).
      # nom: live build progress from nix's JSON log. No -v: nixos-rebuild-ng would print its
      # own debug log (every command it runs) with it.
      nixos-rebuild switch --sudo --flake "$repo#$host" --impure --log-format internal-json |& nom --json \
        || fail "Rebuild failed; the running system is unchanged."

      finish "\033[1;32m✓ $host is up to date.\033[0m" 0
    '';
  };
in
{
  home.packages = [ nixos-update ];
}
