# tpm.nix — TPM 2.0 support + tpm2-passkey (TPM-backed FIDO2/CTAP2 passkeys).
#
# Requires the firmware TPM to be enabled in BIOS first (Intel PTT on this
# Z370 board). Until /dev/tpmrm0 exists, the tpm2-passkey user service stays
# inert (ConditionPathExists), so this module is safe to build and switch
# before the BIOS toggle.
#
# tpm2-passkey (flake input, ~/projects/tpm2-passkey) replaces tpm-fido:
# tpm-fido is U2F-only (no passkeys; sites answer "your device can't be used"),
# and running both makes the browser show two prompts.
#
# Private keys never leave the TPM, but the passkey store (TPM-wrapped keys +
# metadata, AES-encrypted with a TPM-sealed key) lives in
# ~/.local/share/tpm2-passkey and is persisted in modules/persist.nix.
# Clearing the TPM / an fTPM-wiping BIOS update destroys all passkeys, so keep
# a backup authenticator on important accounts.
{ pkgs, ... }:

{
  # TPM 2.0 stack (tss group, udev rules, /dev/tpmrm0), uhid + its udev rule,
  # andrew in `tss`, and the systemd --user service in the graphical session.
  # Prompt: pinentry-qt (pinentry-gnome3 silently fails to show under Hyprland).
  services.tpm2-passkey = {
    enable = true;
    user = "andrew";
  };

  environment.systemPackages = [ pkgs.tpm2-tools ];

  # Optional: hardware-backed PKCS#11 provider (e.g. SSH keys sealed in the
  # TPM, non-exportable).
  # security.tpm2.pkcs11.enable = true;
}
