# pkee (~/projects/pkee): fingerprint-unlocked, fuzzy-searching KeePass launcher that
# replaces the KeePassXC GUI. The database is unlocked with a key file wrapped per device
# by linux-passkey (Secure Enclave / TPM + fingerprint); slots live in <db>.slots/ next to
# it. mainMod + l (Dvorak) opens the popup (home/hyprland.nix); `pkee get <query>` in a shell.
{ config, ... }:
{
  programs.pkee = {
    enable = true;
    database = "${config.home.homeDirectory}/Sync/main.kdbx";
  };
}
