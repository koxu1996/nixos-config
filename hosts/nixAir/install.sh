#!/usr/bin/env bash
# install.sh — install nixAir from the ZFS-enabled USB installer
# (`.#installer-nixAir`). Run as root in the installer:
#
#   mkdir -p /arch && mount -o ro /dev/disk/by-partuuid/23afe87b-b786-4fbd-9696-d487267322ab /arch
#   bash /arch/home/andrew/nixos/hosts/nixAir/install.sh
#
# Nothing is built here: the system closure was built on the Mac's Arch install
# and exported to /arch/home/andrew/nixair-cache: TOPLEVEL, FORMAT and MOUNT
# hold the store paths of the system and of nixAir's disko format/mount scripts.
# Disk writes: ONLY the ZFS partition from disk-ids.nix is formatted (by
# disko, format+mount — never destroy). The ESP is mounted, never formatted.
set -euo pipefail

ARCH_PARTUUID=23afe87b-b786-4fbd-9696-d487267322ab # nvme0n1p5, Arch root (read-only here)
ARCH=/arch
REPO=$ARCH/home/andrew/nixos
CACHE=$ARCH/home/andrew/nixair-cache

step() { printf '\n==> %s\n' "$*"; }

step "Arch root read-only at $ARCH"
mkdir -p "$ARCH"
mountpoint -q "$ARCH" || mount -o ro "/dev/disk/by-partuuid/$ARCH_PARTUUID" "$ARCH"

ESP_UUID=$(nix --extra-experimental-features nix-command eval --raw --file "$REPO/hosts/nixAir/disk-ids.nix" espUuid)
ZFS_PARTUUID=$(nix --extra-experimental-features nix-command eval --raw --file "$REPO/hosts/nixAir/disk-ids.nix" zfsPartUuid)
TOPLEVEL=$(cat "$CACHE/TOPLEVEL")
FORMAT=$(cat "$CACHE/FORMAT")
MOUNT=$(cat "$CACHE/MOUNT")
case "$ESP_UUID$ZFS_PARTUUID" in *0000-0000*) echo "disk-ids.nix still has placeholders" >&2; exit 1;; esac

step "Target partition (will be formatted as ZFS pool mpool):"
lsblk -o NAME,SIZE,FSTYPE,PARTUUID "/dev/disk/by-partuuid/$ZFS_PARTUUID"
read -r -p "Type 'format' to create mpool on it: " answer
[ "$answer" = format ] || { echo "aborted"; exit 1; }

step "disko: create mpool and mount it at /mnt (prebuilt scripts from the cache)"
nix --extra-experimental-features nix-command copy --no-check-sigs --from "file://$CACHE" "$FORMAT" "$MOUNT"
"$FORMAT"
"$MOUNT"

step "Mount nixAir's ESP at /mnt/boot"
mkdir -p /mnt/boot
mount -o fmask=0022,dmask=0022 "/dev/disk/by-uuid/$ESP_UUID" /mnt/boot

step "Copy the prebuilt system into /mnt/nix/store"
nix --extra-experimental-features nix-command copy --no-check-sigs \
  --from "file://$CACHE" --to /mnt "$TOPLEVEL"

step "Install bootloader and system profile"
nixos-install --system "$TOPLEVEL" --no-root-passwd --no-channel-copy

step "Copy ~/nixos into the persisted home"
mkdir -p /mnt/persist/home/andrew
cp -a "$REPO" /mnt/persist/home/andrew/nixos
chown -R 1000:100 /mnt/persist/home/andrew

step "Unmount and export the pool"
umount -R /mnt
zpool export mpool
umount "$ARCH"

step "Done. Reboot, hold the power button and pick NixOS."
