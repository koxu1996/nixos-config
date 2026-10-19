#!/usr/bin/env bash
# Evaluation checks for the two hosts. Never builds anything remotely.
# Usage: tests/check.sh [group...]   groups: nixpc-baseline nixpc-kernel nixair
set -uo pipefail
cd "$(dirname "$0")/.."
NIX=(nix --option builders "" --extra-experimental-features "nix-command flakes")
fail=0
expect() { # name expected actual
  if [ "$2" = "$3" ]; then echo "PASS $1"; else echo "FAIL $1: expected <$2> got <$3>"; fail=1; fi
}
ev() { "${NIX[@]}" eval --impure --raw ".#nixosConfigurations.$1" 2>&1 | tail -1; }
evj() { "${NIX[@]}" eval --impure --json ".#nixosConfigurations.$1" 2>&1 | tail -1; }

nixpc_baseline() { # nixPC must not change while nixAir is added (baseline: kernel 7.2.10, lock 2026-10-15, wallpaper from repo)
  expect nixpc-drv "/nix/store/zpzbwcfqlz5ginpkclr9ny1y37an35w9-nixos-system-nixPC-26.11.20261015.fe13242.drv" \
    "$(ev nixPC.config.system.build.toplevel.drvPath)"
}

nixpc_kernel() { # Task 2: newest kernel that ZFS supports
  v=$(ev nixPC.config.boot.kernelPackages.kernel.version)
  case "$v" in 7.2.*) echo "PASS nixpc-kernel ($v)";; *) echo "FAIL nixpc-kernel: expected 7.2.x got <$v>"; fail=1;; esac
  expect nixpc-zfs-not-broken false "$("${NIX[@]}" eval --impure --json .#nixosConfigurations.nixPC.config --apply 'c: c.boot.kernelPackages.${c.boot.zfs.package.kernelModuleAttribute}.meta.broken or false' 2>&1 | tail -1)"
}

nixair() { # Task 3: MacBook Air host
  expect nixair-hostname nixAir "$(ev nixAir.config.networking.hostName)"
  expect nixair-system aarch64-linux "$(ev nixAir.config.nixpkgs.hostPlatform.system)"
  expect nixair-datasets '["local","local/nix","local/root","local/tmp","safe","safe/persist"]' \
    "$("${NIX[@]}" eval --impure --json .#nixosConfigurations.nixAir.config.disko.devices.zpool.mpool.datasets --apply 'd: builtins.filter (n: n != "__root") (builtins.attrNames d)' 2>&1 | tail -1)"
  expect nixair-no-monero false "$(evj nixAir.config.services.monero.enable)"
  expect nixair-no-steam false "$(evj nixAir.config.programs.steam.enable)"
  expect nixair-no-tpm false "$(evj nixAir.config.security.tpm2.enable)"
  expect nixair-iwd true "$(evj nixAir.config.networking.wireless.iwd.enable)"
  expect nixair-zfs-rollback 'zfs rollback -r mpool/local/root@blank' \
    "$("${NIX[@]}" eval --impure --raw .#nixosConfigurations.nixAir.config.boot.initrd.systemd.services.rollback-root.script 2>&1 | tail -1 | xargs)"
  expect nixair-zfs-not-broken false "$("${NIX[@]}" eval --impure --json .#nixosConfigurations.nixAir.config --apply 'c: c.boot.kernelPackages.${c.boot.zfs.package.kernelModuleAttribute}.meta.broken or false' 2>&1 | tail -1)"
  expect nixpc-monero-kept true "$(evj nixPC.config.services.monero.enable)"
  # disko may only ever touch the ZFS partition, by PARTUUID, and never partition/format anything else.
  local fmt; fmt=$("${NIX[@]}" build --impure --no-link --print-out-paths .#nixosConfigurations.nixAir.config.system.build.formatScript 2>&1 | tail -1)
  if [ -f "$fmt" ]; then
    expect nixair-disko-devices "$(printf '/dev/disk/by-partuuid/%s' "$(ev nixAir.config.disko.devices.disk.nix.device | sed 's|.*/||')")" \
      "$(grep -o '/dev/[A-Za-z0-9/_.:-]*' "$fmt" | grep -v '^/dev/null$' | sort -u | tr '\n' ' ' | xargs)"
    expect nixair-disko-no-partitioning 0 "$(grep -cE 'sgdisk|parted|sfdisk|mkfs|wipefs|blkdiscard' "$fmt")"
  else echo "FAIL nixair-disko: no format script ($fmt)"; fail=1; fi
}

installer() { # Task 5: ZFS-enabled installer for nixAir (eval only; size is checked after the build)
  local inst='.#packages.aarch64-linux.installer-nixAir.config'
  expect installer-zfs true "$("${NIX[@]}" eval --impure --json "$inst.boot.supportedFilesystems.zfs" 2>&1 | tail -1)"
  expect installer-same-kernel "$(ev nixAir.config.boot.kernelPackages.kernel.drvPath)" \
    "$("${NIX[@]}" eval --impure --raw "$inst.boot.kernelPackages.kernel.drvPath" 2>&1 | tail -1)"
  expect installer-same-zfs "$(ev nixAir.config.boot.zfs.package.drvPath)" \
    "$("${NIX[@]}" eval --impure --raw "$inst.boot.zfs.package.drvPath" 2>&1 | tail -1)"
  expect installer-has-disko true "$("${NIX[@]}" eval --impure --json "$inst.environment.systemPackages" --apply 'ps: builtins.any (p: (p.pname or p.name or "") == "disko") ps' 2>&1 | tail -1)"
}

installer_size() { # Task 5: the built ISO must fit the 3.7 GB stick
  local iso; iso=$(ls result-installer/iso/*.iso 2>/dev/null | head -1)
  if [ -n "$iso" ] && [ "$(stat -Lc %s "$iso")" -le 3700000000 ]; then echo "PASS installer-size ($(stat -Lc %s "$iso") bytes)"; else echo "FAIL installer-size: <$iso>"; fail=1; fi
}

nixair_ids() { # Task 6: real partition ids (ESP p4 "EFI - NIXAI", ZFS p9 "nixair-zfs")
  expect nixair-esp-uuid 87A7-1509 "$("${NIX[@]}" eval --raw --file hosts/nixAir/disk-ids.nix espUuid 2>&1 | tail -1)"
  expect nixair-zfs-partuuid 1c94e319-6823-4cb4-b932-16a1e1b1bf17 "$("${NIX[@]}" eval --raw --file hosts/nixAir/disk-ids.nix zfsPartUuid 2>&1 | tail -1)"
  expect nixair-boot-device /dev/disk/by-uuid/87A7-1509 "$(ev 'nixAir.config.fileSystems."/boot".device')"
}

mainmod() { # nixAir: Cmd/Option swapped in the kernel (hid_apple), so Hyprland keeps ALT on both hosts
  local hm='config.home-manager.users.andrew.wayland.windowManager.hyprland.extraConfig'
  expect nixair-mainmod 'local mainMod = "ALT"' "$("${NIX[@]}" eval --impure --raw ".#nixosConfigurations.nixAir.$hm" 2>&1 | grep -o 'local mainMod = "[A-Z]*"')"
  expect nixpc-mainmod 'local mainMod = "ALT"' "$("${NIX[@]}" eval --impure --raw ".#nixosConfigurations.nixPC.$hm" 2>&1 | grep -o 'local mainMod = "[A-Z]*"')"
  expect nixair-swap-opt-cmd 'options hid_apple swap_opt_cmd=1' "$(ev nixAir.config.boot.extraModprobeConfig | grep -o 'options hid_apple swap_opt_cmd=1')"
  expect nixpc-no-swap '' "$(ev nixPC.config.boot.extraModprobeConfig | grep -o 'hid_apple')"
  expect no-mainmod-option false "$("${NIX[@]}" eval --impure --json .#nixosConfigurations.nixAir.config.home-manager.users.andrew --apply 'u: u ? my && u.my ? hyprland' 2>&1 | tail -1)"
}

wallpaper() { # nixAir's wallpaper comes from the repo (store path), not a loose file in $HOME
  local hp; hp=$("${NIX[@]}" eval --impure --raw '.#nixosConfigurations.nixAir.config.home-manager.users.andrew.home.file.".config/hypr/hyprpaper.conf".text' 2>&1 | grep -o 'path = .*')
  case "$hp" in "path = /nix/store/"*-space1.jpg) echo "PASS nixair-hyprpaper-store ($hp)";; *) echo "FAIL nixair-hyprpaper-store: <$hp>"; fail=1;; esac
  local hl; hl=$("${NIX[@]}" eval --impure --raw '.#nixosConfigurations.nixAir.config.home-manager.users.andrew.programs.hyprlock.settings.background' --apply 'bs: (builtins.head bs).path' 2>&1 | tail -1)
  case "$hl" in /nix/store/*-space1.jpg) echo "PASS nixair-hyprlock-store";; *) echo "FAIL nixair-hyprlock-store: <$hl>"; fail=1;; esac
  hp=$("${NIX[@]}" eval --impure --raw '.#nixosConfigurations.nixPC.config.home-manager.users.andrew.home.file.".config/hypr/hyprpaper.conf".text' 2>&1 | grep -o 'path = .*')
  case "$hp" in "path = /nix/store/"*.jpg) echo "PASS nixpc-hyprpaper-store ($hp)";; *) echo "FAIL nixpc-hyprpaper-store: <$hp>"; fail=1;; esac
}

laptop() { # Final review: nixAir laptop fixes
  local hm='.#nixosConfigurations.nixAir.config.home-manager.users.andrew'
  expect nixair-no-dhcpcd false "$(evj nixAir.config.networking.dhcpcd.enable)"
  expect nixair-esp-generations 3 "$(evj nixAir.config.boot.loader.systemd-boot.configurationLimit)"
  local lua; lua=$("${NIX[@]}" eval --impure --raw "$hm.wayland.windowManager.hyprland.extraConfig" 2>&1)
  for k in XF86MonBrightnessUp XF86MonBrightnessDown XF86AudioRaiseVolume XF86AudioLowerVolume XF86AudioMute XF86AudioPlay; do
    if grep -q "\"$k\"" <<<"$lua"; then echo "PASS nixair-key-$k"; else echo "FAIL nixair-key-$k"; fail=1; fi
  done
  if grep -q 'key(mainMod .. " + SHIFT", "s")' <<<"$lua"; then echo "PASS nixair-screenshot-bind"; else echo "FAIL nixair-screenshot-bind"; fail=1; fi
  expect nixair-brightnessctl true "$("${NIX[@]}" eval --impure --json "$hm.home.packages" --apply 'ps: builtins.any (p: (p.pname or "") == "brightnessctl") ps' 2>&1 | tail -1)"
  expect nixair-waybar-battery true "$("${NIX[@]}" eval --impure --json "$hm.programs.waybar.settings.mainBar.modules-right" --apply 'builtins.elem "battery"' 2>&1 | tail -1)"
  expect nixpc-waybar-no-battery false "$("${NIX[@]}" eval --impure --json '.#nixosConfigurations.nixPC.config.home-manager.users.andrew.programs.waybar.settings.mainBar.modules-right' --apply 'builtins.elem "battery"' 2>&1 | tail -1)"
}

bootlogo() { # nixAir: NixOS snowflake as m1n1's boot logo; a 512px copy on the ESP for the boot-picker icon (set from macOS)
  case "$(ev nixAir.config.boot.m1n1CustomLogo)" in /nix/store/*/256x256/apps/nix-snowflake.png) echo "PASS nixair-m1n1-logo";; *) echo "FAIL nixair-m1n1-logo: <$(ev nixAir.config.boot.m1n1CustomLogo)>"; fail=1;; esac
  case "$(ev 'nixAir.config.boot.loader.systemd-boot.extraFiles."nixos-icon.png"')" in /nix/store/*/512x512/apps/nix-snowflake.png) echo "PASS nixair-esp-icon";; *) echo "FAIL nixair-esp-icon"; fail=1;; esac
}

for g in "${@:-nixpc-baseline}"; do "${g//-/_}"; done
exit $fail
