# tpm.nix — TPM 2.0 support + linux-passkey (TPM-backed FIDO2/CTAP2 passkeys).
#
# Requires the firmware TPM to be enabled in BIOS first (Intel PTT on this
# Z370 board). Until /dev/tpmrm0 exists, the linux-passkey user service stays
# inert (ConditionPathExists), so this module is safe to build and switch
# before the BIOS toggle.
#
# linux-passkey (github:koxu1996/linux-passkey, formerly tpm2-passkey)
# replaces tpm-fido:
# tpm-fido is U2F-only (no passkeys; sites answer "your device can't be used"),
# and running both makes the browser show two prompts.
#
# Private keys never leave the TPM, but the passkey store (TPM-wrapped keys +
# metadata, AES-encrypted with a TPM-sealed key) lives in
# ~/.local/share/linux-passkey and is persisted in modules/persist.nix.
# Clearing the TPM / an fTPM-wiping BIOS update destroys all passkeys, so keep
# a backup authenticator on important accounts.
{ pkgs, ... }:

{
  # TPM 2.0 stack (tss group, udev rules, /dev/tpmrm0), uhid + its udev rule,
  # andrew in `tss`, and the systemd --user service in the graphical session.
  # Prompt: pinentry-qt (pinentry-gnome3 silently fails to show under Hyprland).
  services.linux-passkey = {
    enable = true;
    user = "andrew";
  };

  environment.systemPackages = [
    pkgs.tpm2-tools
    pkgs.pam_u2f # pamu2fcfg, to register the passkey for PAM.
  ];

  # sudo, su and polkit prompts: the linux-passkey Confirm dialog instead of the
  # password (pam_u2f, `sufficient`, before pam_unix). Deny, a timeout or a
  # stopped daemon falls back to the password. Login stays password-only: the
  # daemon only runs inside the graphical session, and a session-locked screen
  # (hyprlock) can't show the dialog anyway.
  security.pam.u2f.settings = {
    # Root-owned, so nothing running as andrew can enroll its own key and get
    # password-free sudo (the default ~/.config/Yubico/u2f_keys would allow it).
    # One line per user, from (-r: discoverable; linux-passkey's TPM-wrapped
    # keys don't fit in a non-discoverable credential ID):
    #   pamu2fcfg -r -u andrew -o pam://nixPC -i pam://nixPC
    authfile = "/var/lib/pam-u2f/u2f_mappings";
    origin = "pam://nixPC";
    appid = "pam://nixPC";
    cue = true;
    cue_prompt = "Confirm in the linux-passkey dialog (or Deny for the password)...";
  };
  security.pam.services = {
    sudo.u2f.enable = true;
    su.u2f.enable = true;
    polkit-1.u2f.enable = true;
  };
  environment.persistence."/persist".directories = [
    { directory = "/var/lib/pam-u2f"; mode = "0755"; }
  ];

  # Optional: hardware-backed PKCS#11 provider (e.g. SSH keys sealed in the
  # TPM, non-exportable).
  # security.tpm2.pkcs11.enable = true;
}
