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

nixpc_baseline() { # nixPC must not change while nixAir is added (baseline: kernel 7.2.10, lock 2026-10-15, shared look + clutch)
  expect nixpc-drv "/nix/store/g99nz6z789r24bq5vjlkiizijmxhswlp-nixos-system-nixPC-26.11.20261015.fe13242.drv" \
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
  # iwd's DHCP must hand DNS to resolvconf (NixOS default), not to systemd-resolved which isn't running.
  expect nixair-iwd-dns resolvconf "$(ev nixAir.config.networking.wireless.iwd.settings.Network.NameResolvingService)"
  expect nixair-resolvconf true "$(evj nixAir.config.networking.resolvconf.enable)"
  expect nixair-esp-generations 3 "$(evj nixAir.config.boot.loader.systemd-boot.configurationLimit)"
  local lua; lua=$("${NIX[@]}" eval --impure --raw "$hm.wayland.windowManager.hyprland.extraConfig" 2>&1)
  for k in XF86MonBrightnessUp XF86MonBrightnessDown XF86AudioRaiseVolume XF86AudioLowerVolume XF86AudioMute XF86AudioPlay; do
    if grep -q "\"$k\"" <<<"$lua"; then echo "PASS nixair-key-$k"; else echo "FAIL nixair-key-$k"; fail=1; fi
  done
  if grep -q 'key(mainMod .. " + SHIFT", "s"), hl.dsp.exec_cmd(tools .. "screenshot region")' <<<"$lua"; then echo "PASS nixair-screenshot-bind"; else echo "FAIL nixair-screenshot-bind"; fail=1; fi
  expect nixair-brightnessctl true "$("${NIX[@]}" eval --impure --json "$hm.home.packages" --apply 'ps: builtins.any (p: (p.pname or "") == "brightnessctl") ps' 2>&1 | tail -1)"
}

bootlogo() { # nixAir: NixOS snowflake as m1n1's boot logo; a 512px copy on the ESP for the boot-picker icon (set from macOS)
  case "$(ev nixAir.config.boot.m1n1CustomLogo)" in /nix/store/*/256x256/apps/nix-snowflake.png) echo "PASS nixair-m1n1-logo";; *) echo "FAIL nixair-m1n1-logo: <$(ev nixAir.config.boot.m1n1CustomLogo)>"; fail=1;; esac
  case "$(ev 'nixAir.config.boot.loader.systemd-boot.extraFiles."nixos-icon.png"')" in /nix/store/*/512x512/apps/nix-snowflake.png) echo "PASS nixair-esp-icon";; *) echo "FAIL nixair-esp-icon"; fail=1;; esac
}

install_copy() { # install.sh copies the repo INTO ~/nixos even when activation already created it (impermanence)
  local t; t=$(mktemp -d); mkdir -p "$t/src/hosts" "$t/mnt/persist/home/andrew/nixos"; touch "$t/src/flake.nix"
  local line; line=$(grep -E '^cp -a "\$REPO' hosts/nixAir/install.sh)
  (REPO="$t/src"; cd "$t" && eval "${line//\/mnt\//$t/mnt/}")
  if [ -f "$t/mnt/persist/home/andrew/nixos/flake.nix" ] && [ ! -e "$t/mnt/persist/home/andrew/nixos/src" ]; then echo "PASS install-copy-flat"; else echo "FAIL install-copy-flat: $(cd "$t/mnt/persist/home/andrew/nixos" && ls -A)"; fail=1; fi
  rm -rf "$t"
}

look_files() { # Task 1: the look imported from the Mac's Arch HM config (tests/look-manifest.txt)
  if [ ! -s tests/look-manifest.txt ]; then echo "FAIL look-manifest: missing"; fail=1; return; fi
  # Presence only: the manifest's hashes record the files as imported; later tasks edit them.
  local miss=0 f; while read -r h f; do [ "${h#\#}" = "$h" ] || continue; [ -e "home/look/$f" ] || miss=$((miss+1)); done < tests/look-manifest.txt
  expect look-files-present 0 "$miss"
  [ -f home/look/quickshell/WifiService.qml ] && echo "PASS look-wifiservice" || { echo "FAIL look-wifiservice"; fail=1; }
  [ -f home/look/palette.nix ] && echo "PASS look-palette" || { echo "FAIL look-palette"; fail=1; }
}

look_host() { # Task 2: per-host bar features through my.look.* -> generated Host.qml
  local q
  for h in nixAir nixPC; do
    q=$("${NIX[@]}" eval --impure --raw ".#nixosConfigurations.$h.config.home-manager.users.andrew.my.look.hostQml" 2>/dev/null)
    case $h in
      nixAir) want='wifi: true|battery: true|glowBrightness: true|notchGap: 200|cpuProfile: "battery"';;
      nixPC)  want='wifi: false|battery: false|glowBrightness: false|notchGap: 0|cpuProfile: "stats"';;
    esac
    got=$(grep -oE '(wifi|battery|glowBrightness|notchGap|cpuProfile): [^ ]+' <<<"$q" | tr '\n' '|' | sed 's/|$//')
    expect "look-host-$h" "$want" "$got"
    head -c 200 <<<"$q" | grep -q '{' && ! grep -q '^pragma Singleton' <<<"$(sed '/{/q' <<<"$q")" && { echo "FAIL look-host-pragma-$h"; fail=1; }
  done
  grep -q 'Host.notchGap' home/look/quickshell/shell.qml && ! grep -q 'hasNotch ? 200' home/look/quickshell/shell.qml \
    && echo "PASS look-notch-from-host" || { echo "FAIL look-notch-from-host"; fail=1; }
  grep -q 'active: Host.wifi' home/look/quickshell/shell.qml && grep -q 'active: Host.battery' home/look/quickshell/shell.qml \
    && echo "PASS look-gated-chips" || { echo "FAIL look-gated-chips"; fail=1; }
  grep -q 'Host.glowBrightness' home/look/quickshell/Glow.qml && grep -q 'Host.glowBrightness' home/look/quickshell/GlowService.qml \
    && echo "PASS look-gated-brightness" || { echo "FAIL look-gated-brightness"; fail=1; }
  ! grep -qE '"light"' home/look/quickshell/GlowService.qml && echo "PASS look-no-light" || { echo "FAIL look-no-light"; fail=1; }
}

look_lint() { # Task 2: qmllint over the built bar source (errors only; Quickshell imports are unresolvable here)
  local src; src=$("${NIX[@]}" build --impure --no-link --print-out-paths .#nixosConfigurations.nixAir.config.home-manager.users.andrew.my.look.barSource 2>&1 | tail -1)
  [ -d "$src" ] || { echo "FAIL look-lint: no bar source ($src)"; fail=1; return; }
  local lint; lint=$("${NIX[@]}" shell nixpkgs#kdePackages.qtdeclarative -c sh -c "cd $src && qmllint --compiler disable --unqualified disable --import disable --unused-imports disable --missing-property disable --missing-type disable --unresolved-type disable --type disable --incompatible-type disable --signal-handler-parameters disable --property-alias-cycles disable --deprecated disable *.qml 2>&1")
  local errs; errs=$(grep -cE '^Error|: error|SyntaxError|Expected token|\[syntax\]' <<<"$lint" || true)
  expect look-lint-errors 0 "$errs"
  [ "$errs" = 0 ] || grep -E '^Error|: error|SyntaxError|Expected token|\[syntax\]' <<<"$lint" | head -10
}

look_session() { # Task 3: bar + hyprsunset in HM; waybar, mako, wlsunset gone; config links; state persisted
  local u
  for h in nixAir nixPC; do
    u="$h.config.home-manager.users.andrew"
    expect "look-$h-quickshell" true "$(evj $u.programs.quickshell.enable)"
    expect "look-$h-hyprsunset" true "$(evj $u.services.hyprsunset.enable)"
    expect "look-$h-no-waybar" false "$(evj $u.programs.waybar.enable)"
    expect "look-$h-no-mako" false "$(evj $u.services.mako.enable)"
    expect "look-$h-no-wlsunset" false "$("${NIX[@]}" eval --impure --json ".#nixosConfigurations.$u.home.packages" --apply 'ps: builtins.any (p: (p.pname or "") == "wlsunset") ps' 2>&1 | tail -1)"
    for f in launcher/launcher.json:launcher.json glow/profiles.json:glow-profiles.json clock/config.json:clock-config.json; do
      local link=${f%%:*} file=${f#*:}
      expect "look-$h-link-$file" "/home/andrew/nixos/home/look/quickshell/$file" \
        "$("${NIX[@]}" derivation show "$("${NIX[@]}" eval --impure --raw ".#nixosConfigurations.$u.xdg.configFile.\"quickshell/$link\".source.drvPath" 2>/dev/null)" 2>/dev/null | grep -o "/home/andrew/nixos/home/look/quickshell/$file" | head -1)"
    done
    expect "look-$h-persist-state" true "$("${NIX[@]}" eval --impure --json ".#nixosConfigurations.$h.config.environment.persistence.\"/persist\".users.andrew.directories" --apply 'ds: builtins.any (d: (d.directory or d) == ".local/state/quickshell") ds' 2>&1 | tail -1)"
    local env; env=$("${NIX[@]}" eval --impure --json ".#nixosConfigurations.$u.systemd.user.services.quickshell.Service.Environment" 2>&1 | tail -1)
    for d in /run/wrappers/bin /etc/profiles/per-user/andrew/bin /run/current-system/sw/bin; do
      grep -q "$d" <<<"$env" && echo "PASS look-$h-path-$d" || { echo "FAIL look-$h-path-$d: $env"; fail=1; }
    done
  done
  expect look-nixAir-brightnessctl true "$("${NIX[@]}" eval --impure --json '.#nixosConfigurations.nixAir.config.home-manager.users.andrew.home.packages' --apply 'ps: builtins.any (p: (p.pname or "") == "brightnessctl") ps' 2>&1 | tail -1)"
  [ ! -e home/waybar.nix ] && echo "PASS look-waybar-file-gone" || { echo "FAIL look-waybar-file-gone"; fail=1; }
}

look_terminal() { # Task 4: Alacritty, tmux, prompt in the lime palette on both hosts
  local u t
  for h in nixAir nixPC; do
    u=".#nixosConfigurations.$h.config.home-manager.users.andrew"
    t=$("${NIX[@]}" eval --impure --json "$u.programs.alacritty.settings" 2>&1 | tail -1)
    grep -q '#c5f36a' <<<"$t" && grep -q 'JetBrains Mono' <<<"$t" && echo "PASS look-$h-alacritty" || { echo "FAIL look-$h-alacritty"; fail=1; }
    t=$("${NIX[@]}" eval --impure --raw "$u.xdg.configFile.\"tmux/tmux.conf\".text" 2>&1)
    for want in 'bind t select-pane -D' 'bind s select-pane -R' 'status-left ""' '#262d1d' 'prefix C-a'; do
      grep -qF "$want" <<<"$t" && echo "PASS look-$h-tmux:$want" || { echo "FAIL look-$h-tmux:$want"; fail=1; }
    done
    grep -q '/bin/zsh"' <<<"$t" && grep -q 'default-shell "/bin/zsh"' <<<"$t" && { echo "FAIL look-$h-tmux-shell: /bin/zsh does not exist on NixOS"; fail=1; } || echo "PASS look-$h-tmux-shell"
    expect "look-$h-omz-theme" '""' "$(evj ${u#.#nixosConfigurations.}.programs.zsh.oh-my-zsh.theme)"
    "${NIX[@]}" eval --impure --raw "$u.programs.zsh.initContent" 2>&1 | grep -q 'zsh/prompt.zsh' && echo "PASS look-$h-prompt-sourced" || { echo "FAIL look-$h-prompt-sourced"; fail=1; }
    expect "look-$h-fonts" true "$("${NIX[@]}" eval --impure --json ".#nixosConfigurations.$h.config.fonts.packages" --apply 'ps: let n = map (p: p.pname or "") ps; in builtins.elem "jetbrains-mono" n && builtins.elem "inter" n' 2>&1 | tail -1)"
  done
}

look_hyprland() { # Task 5: the Mac's Hyprland behaviour on both hosts, no Arch leftovers, no key bound twice
  local lua
  for h in nixAir nixPC; do
    lua=$("${NIX[@]}" eval --impure --raw ".#nixosConfigurations.$h.config.home-manager.users.andrew.wayland.windowManager.hyprland.extraConfig" 2>/dev/null)
    for want in toggle_dropterm 'special:dropterm' 'call launcher toggle' 'hl.on("window.open"' 'evict_from_dropterm' 'bar call tools ' 'tools .. "screenshot region"' 'bar call media ' 'mpris .. "playPause"' 'dim_special = 0' 'hy3.make_group'; do
      grep -qF "$want" <<<"$lua" && echo "PASS look-$h-hl:$want" || { echo "FAIL look-$h-hl:$want"; fail=1; }
    done
    for bad in wlsunset swaylock 'light -' floating_terminal_1 appLauncher 'Application launcher - System'; do
      grep -qF "$bad" <<<"$lua" && { echo "FAIL look-$h-hl-leftover:$bad"; fail=1; } || echo "PASS look-$h-hl-no:$bad"
    done
    # Every bind's key argument once only (key(...) calls and literal "XF86..." strings).
    local dup; dup=$(grep -oE 'hl\.bind\((key\([^)]*\)|"[^"]+"|mainMod \.\. "[^"]+")' <<<"$lua" | sort | uniq -d)
    expect "look-$h-hl-no-duplicate-binds" "" "$dup"
  done
  # Fullscreen keeping the bar row: only where there is a notch (Andrew: real fullscreen on nixPC).
  local airLua pcLua
  airLua=$("${NIX[@]}" eval --impure --raw ".#nixosConfigurations.nixAir.config.home-manager.users.andrew.wayland.windowManager.hyprland.extraConfig" 2>/dev/null)
  pcLua=$("${NIX[@]}" eval --impure --raw ".#nixosConfigurations.nixPC.config.home-manager.users.andrew.wayland.windowManager.hyprland.extraConfig" 2>/dev/null)
  grep -qF '"window.fullscreen"' <<<"$airLua" && grep -qF 'workspace = "f[1]"' <<<"$airLua" && echo "PASS nixair-notch-fullscreen" || { echo "FAIL nixair-notch-fullscreen"; fail=1; }
  ! grep -qF '"window.fullscreen"' <<<"$pcLua" && ! grep -qF 'fullscreen_state' <<<"$pcLua" && grep -qF 'hl.bind(key(mainMod, "f"), hl.dsp.window.fullscreen())' <<<"$pcLua" \
    && echo "PASS nixpc-real-fullscreen" || { echo "FAIL nixpc-real-fullscreen"; fail=1; }
  expect nixair-kernel-notch true "$("${NIX[@]}" eval --impure --json .#nixosConfigurations.nixAir.config.boot.kernelParams --apply 'ps: builtins.elem "appledrm.show_notch=1" ps && builtins.elem "brcmfmac.feature_disable=0x82000" ps' 2>&1 | tail -1)"
  expect nixpc-kernel-no-notch false "$("${NIX[@]}" eval --impure --json .#nixosConfigurations.nixPC.config.boot.kernelParams --apply 'builtins.elem "appledrm.show_notch=1"' 2>&1 | tail -1)"
}

cpu_profile() { # Task 6: cpu-profile helper + polkit on both hosts; per-CPU scripts; bar shows it per host
  local h
  for h in nixAir nixPC; do
    "${NIX[@]}" eval --impure --json ".#nixosConfigurations.$h.config.systemd.tmpfiles.rules" 2>&1 | grep -q 'L+ /usr/local/bin/cpu-profile' \
      && echo "PASS cpu-$h-tmpfiles" || { echo "FAIL cpu-$h-tmpfiles"; fail=1; }
    "${NIX[@]}" eval --impure --raw ".#nixosConfigurations.$h.config.security.polkit.extraConfig" 2>&1 | grep -q 'subject.user == "andrew"' \
      && echo "PASS cpu-$h-polkit" || { echo "FAIL cpu-$h-polkit"; fail=1; }
  done
  grep -q energy_performance_preference hosts/nixPC/cpu-profile 2>/dev/null && grep -q no_turbo hosts/nixPC/cpu-profile \
    && echo "PASS cpu-nixPC-intel" || { echo "FAIL cpu-nixPC-intel"; fail=1; }
  grep -q policy4 hosts/nixAir/cpu-profile 2>/dev/null && echo "PASS cpu-nixAir-m2" || { echo "FAIL cpu-nixAir-m2"; fail=1; }
  local sc; sc=$("${NIX[@]}" run nixpkgs#shellcheck -- -s sh hosts/nixPC/cpu-profile hosts/nixAir/cpu-profile 2>/dev/null); expect cpu-shellcheck "" "$sc"

  # nixPC helper against a fake sysfs (2 CPUs).
  local t; t=$(mktemp -d)
  for c in 0 1; do mkdir -p "$t/devices/system/cpu/cpu$c/cpufreq"; echo powersave > "$t/devices/system/cpu/cpu$c/cpufreq/scaling_governor"; echo balance_power > "$t/devices/system/cpu/cpu$c/cpufreq/energy_performance_preference"; done
  mkdir -p "$t/devices/system/cpu/intel_pstate"; echo 0 > "$t/devices/system/cpu/intel_pstate/no_turbo"
  local prof want got
  for prof in saver:powersave:power:1 balanced:powersave:balance_performance:0 performance:performance:performance:0; do
    IFS=: read -r name gov epp nt <<<"$prof"
    CPU_SYSFS_ROOT=$t sh hosts/nixPC/cpu-profile "$name" >/dev/null 2>&1
    got="$(cat $t/devices/system/cpu/cpu1/cpufreq/scaling_governor) $(cat $t/devices/system/cpu/cpu1/cpufreq/energy_performance_preference) $(cat $t/devices/system/cpu/intel_pstate/no_turbo)"
    expect "cpu-nixPC-set-$name" "$gov $epp $nt" "$got"
    expect "cpu-nixPC-status-$name" "profile=$name" "$(CPU_SYSFS_ROOT=$t sh hosts/nixPC/cpu-profile 2>/dev/null | head -1)"
  done
  CPU_SYSFS_ROOT=$t sh hosts/nixPC/cpu-profile turbo >/dev/null 2>&1; expect cpu-nixPC-rejects-bad-arg 2 "$?"
  rm -rf "$t"

  # nixAir helper status against a fake M2 cpufreq tree (balanced: schedutil, full range, boost off).
  t=$(mktemp -d); local P=$t/devices/system/cpu/cpufreq
  mkdir -p "$P/policy0" "$P/policy4"; echo 0 > "$P/boost"
  for pol in policy0 policy4; do echo schedutil > "$P/$pol/scaling_governor"; done
  echo "600000 2424000" > "$P/policy0/scaling_available_frequencies"; echo 600000 > "$P/policy0/scaling_min_freq"; echo 2424000 > "$P/policy0/scaling_max_freq"
  echo "660000 2000000 3204000" > "$P/policy4/scaling_available_frequencies"; echo 660000 > "$P/policy4/scaling_min_freq"; echo 3204000 > "$P/policy4/scaling_max_freq"
  expect cpu-nixAir-status-balanced profile=balanced "$(CPU_SYSFS_ROOT=$t sh hosts/nixAir/cpu-profile 2>/dev/null | head -1)"
  echo 2000000 > "$P/policy4/scaling_max_freq"
  expect cpu-nixAir-status-saver profile=saver "$(CPU_SYSFS_ROOT=$t sh hosts/nixAir/cpu-profile 2>/dev/null | head -1)"
  rm -rf "$t"

  # QML: one service, shown per host.
  [ -f home/look/quickshell/CpuProfileService.qml ] && ! grep -q profileRunner home/look/quickshell/BatteryService.qml \
    && echo "PASS cpu-qml-service" || { echo "FAIL cpu-qml-service"; fail=1; }
  grep -q 'Host.cpuProfile === "battery"' home/look/quickshell/Battery.qml && grep -q 'Host.cpuProfile === "stats"' home/look/quickshell/SystemStats.qml \
    && echo "PASS cpu-qml-placement" || { echo "FAIL cpu-qml-placement"; fail=1; }
}

wifi_iwd() { # Task 7: Wi-Fi chip on iwd (D-Bus via busctl, iwctl for new passwords)
  local out; out=$("${NIX[@]}" run nixpkgs#nodejs -- tests/iwd/iwd.test.js 2>&1 | tail -3)
  grep -q 'all assertions passed' <<<"$out" && echo "PASS wifi-iwd-parser" || { echo "FAIL wifi-iwd-parser: $out"; fail=1; }
  local left; left=$(grep -rlE 'netctl|wpa_cli|wifi-ctl' home/look 2>/dev/null | tr '\n' ' ')
  expect wifi-no-netctl "" "$left"
  grep -q 'import "iwd.js" as Iwd' home/look/quickshell/WifiService.qml && echo "PASS wifi-service-uses-iwd" || { echo "FAIL wifi-service-uses-iwd"; fail=1; }
  expect wifi-andrew-wheel true "$("${NIX[@]}" eval --impure --json .#nixosConfigurations.nixAir.config.users.users.andrew.extraGroups --apply 'builtins.elem "wheel"' 2>&1 | tail -1)"
  local iwd; iwd=$("${NIX[@]}" build --impure --no-link --print-out-paths .#nixosConfigurations.nixAir.config.networking.wireless.iwd.package 2>/dev/null | grep -v -- '-man$' | tail -1)
  grep -q '<policy group="wheel">' "$iwd/share/dbus-1/system.d/iwd-dbus.conf" 2>/dev/null && echo "PASS wifi-iwd-dbus-wheel" || { echo "FAIL wifi-iwd-dbus-wheel ($iwd)"; fail=1; }
}

review_fixes() { # Final review: pkexec realities (resolved store path, stripped PATH) and the bar scripts' tools
  local h pkg
  for h in nixAir nixPC; do
    "${NIX[@]}" eval --impure --raw ".#nixosConfigurations.$h.config.security.polkit.extraConfig" 2>&1 \
      | grep -qE '"/nix/store/[a-z0-9]+-cpu-profile/bin/cpu-profile"' && echo "PASS fix-$h-polkit-storepath" || { echo "FAIL fix-$h-polkit-storepath"; fail=1; }
    for pkg in jq grim slurp wl-clipboard libnotify; do
      expect "fix-$h-has-$pkg" true "$("${NIX[@]}" eval --impure --json ".#nixosConfigurations.$h.config" --apply "c: builtins.any (p: (p.pname or \"\") == \"$pkg\") (c.environment.systemPackages ++ c.home-manager.users.andrew.home.packages)" 2>&1 | tail -1)"
    done
  done
  # Stats panel describes each machine (Host.qml), not the MacBook everywhere.
  local q
  q=$("${NIX[@]}" eval --impure --raw .#nixosConfigurations.nixPC.config.home-manager.users.andrew.my.look.hostQml 2>/dev/null)
  grep -q 'machineName: "Workstation · i7-9700"' <<<"$q" && grep -q 'tempLabel: "Package id 0"' <<<"$q" && grep -q 'powerLabel: ""' <<<"$q" && grep -q 'eCores: \[\]' <<<"$q" \
    && echo "PASS fix-nixPC-machine" || { echo "FAIL fix-nixPC-machine"; fail=1; }
  q=$("${NIX[@]}" eval --impure --raw .#nixosConfigurations.nixAir.config.home-manager.users.andrew.my.look.hostQml 2>/dev/null)
  grep -q 'machineName: "MacBook Air · M2"' <<<"$q" && grep -q 'tempLabel: "WiFi/BT Module Temp"' <<<"$q" && grep -q 'eCores: \[0, 1, 2, 3\]' <<<"$q" \
    && echo "PASS fix-nixAir-machine" || { echo "FAIL fix-nixAir-machine"; fail=1; }
  ! grep -q '"MacBook Air · M2"\|4 E-cores + 4 P-cores' home/look/quickshell/SystemStats.qml && grep -q 'Host.machineName' home/look/quickshell/SystemStats.qml \
    && grep -q 'visible: Host.powerLabel !== ""' home/look/quickshell/SystemStats.qml && grep -q 'Host.tempLabel' home/look/quickshell/StatsService.qml \
    && echo "PASS fix-stats-from-host" || { echo "FAIL fix-stats-from-host"; fail=1; }

  # nixAir's installed helper runs with pkexec's PATH (nothing useful on NixOS) against a fake M2 sysfs.
  local bin; bin=$("${NIX[@]}" build --impure --no-link --print-out-paths .#nixosConfigurations.nixAir.config.my.cpuProfile.package 2>/dev/null | tail -1)
  local t; t=$(mktemp -d); local P=$t/devices/system/cpu/cpufreq
  mkdir -p "$P/policy0" "$P/policy4"; echo 0 > "$P/boost"
  for pol in policy0 policy4; do echo schedutil > "$P/$pol/scaling_governor"; done
  echo "600000 2424000" > "$P/policy0/scaling_available_frequencies"; echo 600000 > "$P/policy0/scaling_min_freq"; echo 2424000 > "$P/policy0/scaling_max_freq"
  echo "660000 2000000 3204000" > "$P/policy4/scaling_available_frequencies"; echo 660000 > "$P/policy4/scaling_min_freq"; echo 3204000 > "$P/policy4/scaling_max_freq"
  expect fix-nixAir-helper-bare-path "profile=balanced" "$(env -i PATH=/nonexistent CPU_SYSFS_ROOT=$t "$bin/bin/cpu-profile" 2>&1 | head -1)"
  env -i PATH=/nonexistent CPU_SYSFS_ROOT=$t "$bin/bin/cpu-profile" saver >/dev/null 2>&1; local rc=$?; expect fix-nixAir-helper-bare-path-set "0 2000000" "$rc $(cat $P/policy4/scaling_max_freq)"
  rm -rf "$t"
}

for g in "${@:-nixpc-baseline}"; do "${g//-/_}"; done
exit $fail
