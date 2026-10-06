# tpm.nix — TPM 2.0 support + tpm-fido (TPM-backed FIDO2/U2F authenticator).
#
# Requires the firmware TPM to be enabled in BIOS first (Intel PTT on this
# Z370 board — see the notes in chat). Until /dev/tpmrm0 exists, the tpm-fido
# service below stays inert (ConditionPathExists), so this module is safe to
# build and switch before the BIOS toggle.
#
# tpm-fido keeps NO local state: FIDO private keys are sealed by the TPM and
# the wrapped handle is stored server-side in each site's credential ID. So it
# needs no /persist exception and survives the impermanence root rollback -
# what must persist is the TPM's Owner-hierarchy seed (in firmware), not the
# filesystem. Clearing the TPM / an fTPM-wiping BIOS update destroys all
# credentials, so register a backup authenticator on important accounts.
{ pkgs, ... }:

{
  # 1. TPM 2.0 stack: creates the `tss` group, udev rules, and kernel
  #    resource-manager access at /dev/tpmrm0.
  security.tpm2.enable = true;
  # Optional: hardware-backed PKCS#11 provider (e.g. SSH keys sealed in the
  # TPM, non-exportable). Enable if you want the SSH-key-at-rest angle.
  # security.tpm2.pkcs11.enable = true;

  # andrew needs the tss group to talk to /dev/tpmrm0. (extraGroups merges with
  # the list in configuration.nix.)
  users.users.andrew.extraGroups = [ "tss" ];

  # 2. tpm-fido exposes a virtual FIDO HID device via /dev/uhid. Load the
  #    module and grant access. NOTE: /dev/uhid is a `misc` device, not a seat
  #    device, so logind's `uaccess` ACL never applies to it (it's a no-op).
  #    Grant access via the tss group instead (andrew is already a member).
  boot.kernelModules = [ "uhid" ];
  services.udev.extraRules = ''
    KERNEL=="uhid", SUBSYSTEM=="misc", GROUP="tss", MODE="0660"
  '';

  environment.systemPackages = [ pkgs.tpm-fido pkgs.tpm2-tools ];

  # 3. Run tpm-fido inside the graphical session (it needs the Wayland display
  #    for its user-presence prompt). Guarded on the TPM device so it does not
  #    crash-loop before PTT is enabled.
  systemd.user.services.tpm-fido = {
    description = "tpm-fido — TPM-backed FIDO2/U2F authenticator";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    unitConfig.ConditionPathExists = "/dev/tpmrm0";
    # tpm-fido shells out to a `pinentry` program for the touch/confirm prompt;
    # it must be on PATH and able to reach the Hyprland/Wayland session. If the
    # prompt never appears, try pkgs.pinentry-qt or pkgs.pinentry-all instead.
    path = [ pkgs.pinentry-gnome3 ];
    serviceConfig = {
      ExecStart = "${pkgs.tpm-fido}/bin/tpm-fido";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
