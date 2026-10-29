# TEMPORARY: why does "Failed to unmount /persist" show at poweroff? journald stops writing
# before the final unmounts, so those messages never reach the journal. This system-shutdown
# hook runs after systemd-shutdown's unmount attempts, right before power-off, and saves the
# kernel log (systemd-shutdown logs there), what is still mounted and what still runs to
# the ESP: /boot/shutdown-log/<time>-<poweroff|reboot>.txt.
# For details on each unmount attempt: `sudo systemd-analyze log-level debug` before poweroff.
# Remove this module once the cause is fixed.
{ config, lib, pkgs, ... }:

let
  esp = config.fileSystems."/boot".device;
in
{
  systemd.shutdown.shutdown-log = pkgs.writeShellScript "shutdown-log" ''
    export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.util-linux pkgs.procps ]}

    # /boot is normally unmounted by now; if it is still there (read-only), reuse it.
    if mountpoint -q /boot; then
      mount -o remount,rw /boot || exit 0
      dir=/boot
    else
      dir=/run/shutdown-log
      mkdir -p "$dir"
      mount -t vfat ${esp} "$dir" || exit 0
    fi

    mkdir -p "$dir/shutdown-log"
    {
      echo "== $1"
      echo "== still mounted"
      cat /proc/self/mountinfo
      echo "== processes"
      ps -eo pid,ppid,stat,args
      echo "== kernel log"
      dmesg
    } > "$dir/shutdown-log/$(date +%Y%m%d-%H%M%S)-$1.txt"

    sync
    [ "$dir" = /boot ] || umount "$dir"
  '';
}
