# Identifiers of nixAir's own partitions on the Mac's internal disk.
# Read them with `lsblk -o NAME,UUID,PARTUUID`.
{
  # vfat UUID of the ESP created by the Asahi installer ("UEFI environment only").
  espUuid = "87A7-1509"; # nvme0n1p4, "EFI - NIXAI…", created 2026-10-19
  # GPT PARTUUID of the partition holding the mpool ZFS pool.
  zfsPartUuid = "1c94e319-6823-4cb4-b932-16a1e1b1bf17"; # nvme0n1p5, "nixair-zfs", 1.81 TB
}
