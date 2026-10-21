# Touch ID on nixAir through the Secure Enclave.
#
# The enclave (SEP) does enrolment and matching; Linux only asks. Three pieces
# layered on the stock Asahi stack, nothing else changes:
#   1. Kernel: linux-asahi rebuilt from aurora-silicon/linux `feat/sep`, which
#      adds the `apple_sep` driver (/dev/sep-bio).      -> touchid/linux-asahi-sep.nix
#   2. m1n1: one patch so the bootloader stops poking the SEP for an RNG seed;
#      on M2 that query breaks the Touch ID registration iBoot hands over.
#   3. Userspace: Aurora's libfprint driver for /dev/sep-bio (fprintd stays
#      stock) and the loader/calibration services from nixos-aurora.
#
# Read HANDOVER-touchid.md at the repo root before changing anything here, and
# touchid/aurora-sep/XART-SAFETY.md before setting my.touchid.xartWrites.
{ config, lib, pkgs, ... }:

let
  cfg = config.my.touchid;
  aurora-sep = pkgs.callPackage ./touchid/aurora-sep/package.nix { };
  # Persistent SEP state. The kernel driver writes these fixed paths under
  # /var/lib (store.rs, catacomb.rs, keybag/refkey in sep.rs); / is rolled back
  # every boot, so they are symlinks into /persist. The driver opens them with
  # O_CREAT and follows symlinks, so a dangling link is created in place.
  persistDir = "/persist/sep-state";
  stateFiles = [
    "aurora-sep-host-state.bin"
    "aurora-sep-keybag.bin"
    "aurora-sep-refkey.bin"
    "apple-sep-catacomb-master.bin"
    "apple-sep-catacomb-owner.bin"
    "apple-sep-catacomb-user.bin"
  ];
in
{
  options.my.touchid = {
    enable = lib.mkEnableOption "Touch ID via the Secure Enclave (apple_sep)";
    xartWrites = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Let apple_sep write to the xART anti-replay store that iBoot and macOS
        share (the .gl file in the iBootSystemContainer partition) and provision
        the identity keybag. Required for enrolment and verification to work at
        all; with it off the driver attaches read-only and refuses captures.
        Turn on only after a clean read-only boot and with a verified backup of
        the partition (see HANDOVER-touchid.md).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (final: prev: {
        # 1. Kernel. nixos-apple-silicon's kernel module does
        #    `hardware.asahi.pkgs.linux-asahi.override { _kernelPatches = ...; }`,
        #    which this package honours, and hardware.asahi.pkgs is `pkgs`, so
        #    the overlay reaches it. Its own overlay is mkBefore; this one wins.
        linux-asahi = final.callPackage ./touchid/linux-asahi-sep.nix { };

        # 2. m1n1 (nixpkgs 2.0.0). Rebased from aurora-silicon/m1n1#3: on M2+
        #    seed KASLR/RNG from the ADT instead of the SEP mailbox and drop the
        #    early sep_init(); also forward /chosen/apfs-preboot-uuid to the FDT,
        #    which apple_sep uses as the OS identity for its enrolments.
        #    boot.m1n1CustomLogo still applies (override survives overrideAttrs).
        m1n1 = prev.m1n1.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ./touchid/m1n1-v2.0.0-sep-warm-registration.patch ];
        });

        # 3. libfprint 1.94.100 with the `aurora` driver (/dev/sep-bio, ioctl ABI
        #    v4), retries for unusable captures, and no reader while the lid is
        #    closed. Same patch set as nixos-aurora; verified to apply in order.
        libfprint = prev.libfprint.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            ./touchid/libfprint/libfprint-1.94.100-apple-sep.patch
            ./touchid/libfprint/0002-aurora-report-unusable-captures-as-retries.patch
            ./touchid/libfprint/0003-hide-lid-covered-readers-while-the-lid-is-closed.patch
          ];
          postPatch = (old.postPatch or "") + ''
            install -Dm644 ${./touchid/libfprint/apple-sep.h} aurora-uapi/linux/apple-sep.h
          '';
          preConfigure = (old.preConfigure or "") + ''
            export CFLAGS="''${CFLAGS:-} -I$PWD/aurora-uapi"
          '';
          # 0003 reads the lid switch through umockdev-backed tests.
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.umockdev ];
        });
      })
    ];

    # The driver must not autoload from the modalias: it needs /var (state) and
    # /lib/firmware (calibration) first. aurora-sep.service loads it explicitly.
    boot.blacklistedKernelModules = [ "apple_sep" ];

    # The kernel has the TPM and TEE trusted-key sources built in (Asahi config defaults);
    # the trusted core binds the first one that inits at boot, so apple_sep's source
    # ("applesep", trusted_shim.c) later hit EBUSY. Name it explicitly instead.
    boot.kernelParams = [ "trusted.source=applesep" ];

    environment.systemPackages = [ aurora-sep pkgs.libfprint pkgs.fprintd ];
    services.fprintd.enable = true;

    # --- persistent state ---------------------------------------------------
    environment.persistence."/persist".directories = [
      { directory = "/var/lib/aurora-sep"; mode = "0700"; } # calibration cache + identity
      "/var/lib/fprint" # fprintd's per-user print index (host side of enrolments)
    ];
    systemd.tmpfiles.rules =
      [ "d ${persistDir} 0700 root root -" ]
      ++ map (f: "L+ /var/lib/${f} - - - - ${persistDir}/${f}") stateFiles;

    # --- services (adapted from nixos-aurora modules/sep.nix) -----------------
    systemd.timers.aurora-sep = {
      description = "Initialize Apple SEP after persistent storage is available";
      wantedBy = [ "timers.target" ];
      timerConfig.OnBootSec = "1";
      timerConfig.Unit = "aurora-sep.service";
    };
    systemd.services.aurora-sep = {
      description = "Apple SEP trusted keys and Touch ID (apple_sep loader)";
      # The SEP handoff happens once per boot and module parameters are fixed at load:
      # never let nixos-rebuild switch stop or restart this. A changed loader takes
      # effect on the next boot.
      restartIfChanged = false;
      stopIfChanged = false;
      after = [ "local-fs.target" "systemd-tmpfiles-setup.service" ];
      wants = [ "aurora-sep-ready.service" ];
      unitConfig = {
        RequiresMountsFor = [ "/var/lib" "/persist" ];
        ConditionPathExists = "/dev/disk/by-partlabel/iBootSystemContainer";
      };
      path = [ pkgs.kmod pkgs.gnugrep ];
      environment = {
        TOUCHID_XART_WRITES = if cfg.xartWrites then "1" else "0";
        TOUCHID_FIRMWARE_DIR = "/lib/firmware";
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecCondition = "${pkgs.runtimeShell} -c 'modinfo -F filename apple_sep 2>/dev/null | grep -Eq \"[.]ko([.](gz|xz|zst))?$\"'";
        # Carve this Mac's Mesa calibration out of the iBoot container (read-only)
        # into /var/lib/aurora-sep, then publish it at /lib/firmware/apple/<name>
        # where the kernel's fallback firmware search finds it.
        ExecStartPre = "${aurora-sep}/libexec/aurora/prepare-sep-calibration";
        ExecStart = "${aurora-sep}/libexec/aurora-sep-load";
        StateDirectory = "aurora-sep";
        StateDirectoryMode = "0700";
        TimeoutStartSec = 180;
      };
    };
    systemd.services.aurora-sep-ready = {
      restartIfChanged = false; # same once-per-boot rule as aurora-sep
      description = "Restore fingerprint reader state";
      requires = [ "aurora-sep.service" ];
      after = [ "aurora-sep.service" ];
      before = [ "fprintd.service" ];
      unitConfig.ConditionPathExists = "/dev/sep-bio";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecCondition = "${aurora-sep}/libexec/aurora/sensor-present";
        ExecStart = "${aurora-sep}/libexec/aurora-sep-ready";
        TimeoutStartSec = 60;
      };
    };
    systemd.services.fprintd = {
      requires = [ "aurora-sep.service" ];
      after = [ "aurora-sep.service" "aurora-sep-ready.service" ];
      unitConfig.ConditionPathExists = "/dev/sep-bio";
      serviceConfig.ExecCondition = "${aurora-sep}/libexec/aurora/sensor-present";
      serviceConfig.DeviceAllow = [ "/dev/sep-bio rw" "char-input r" ];
    };
  };
}
