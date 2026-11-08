# Machine recipes for this flake. `just` lists them.

# The flake's hosts are named after the machines (nixAir, nixPC, nuc, nixvps).
host := `hostname`

default:
    @just --list

# Build and switch a host: this machine by default, or `just switch nuc` / `nixvps`,
# built on the target itself over SSH. --impure: nixAir's firmware is outside the flake.
switch target=host:
    nixos-rebuild switch --sudo --flake .#{{target}} \
        {{ if target == host { "" } else { "--target-host " + target + " --build-host " + target } }} \
        {{ if target == "nixAir" { "--impure" } else { "" } }}
