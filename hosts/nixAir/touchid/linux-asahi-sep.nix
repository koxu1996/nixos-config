# linux-asahi with Touch ID: the Asahi kernel package from nixos-apple-silicon
# (apple-silicon-support/packages/linux-asahi/default.nix), with the source
# swapped for aurora-silicon/linux `feat/sep`. That branch is Asahi 7.1.9 plus
# the `apple_sep` Secure Enclave driver (Touch ID over /dev/sep-bio, SEP hwrng,
# SEP-backed trusted keys). Everything else - Rust, 16K pages, the Asahi
# config - is kept exactly as nixos-apple-silicon builds it.
#
# Why a copy and not `.override`: the upstream function's argument set is
# closed, so neither `src` nor `version` can be injected from outside.
#
# Pinned to the merge of aurora-silicon/linux#152 (T8112 profile, J413/J415
# device trees), 2026-10-08. Bump rev + hash together:
#   nix-prefetch-url --unpack https://github.com/aurora-silicon/linux/archive/<rev>.tar.gz
#   nix hash convert --hash-algo sha256 --to sri <hash>
{
  lib,
  callPackage,
  linuxPackagesFor,
  _kernelPatches ? [ ],
}:

let
  linux-asahi-pkg =
    {
      stdenv,
      lib,
      fetchFromGitHub,
      buildLinux,
      ...
    }:
    buildLinux rec {
      inherit stdenv lib;

      pname = "linux-asahi";
      # Must match the source tree's Makefile (VERSION.PATCHLEVEL.SUBLEVEL,
      # empty EXTRAVERSION), otherwise module installation looks in the
      # wrong /lib/modules directory.
      version = "7.1.9";
      modDirVersion = version;
      extraMeta.branch = "7.1";

      src = fetchFromGitHub {
        owner = "aurora-silicon";
        repo = "linux";
        rev = "120e030eac9fc34b1586b9a9a6bf365959828e7a"; # feat/sep
        hash = "sha256-zoFo7xlUtB/bY3p2Vbez5WYnOqD6xYdVuGjKUdFB9ys=";
      };

      kernelPatches = [
        {
          # Verbatim from nixos-apple-silicon.
          name = "Asahi config";
          patch = null;
          structuredExtraConfig = with lib.kernel; {
            # Needed for GPU
            ARM64_16K_PAGES = yes;

            ARM64_MEMORY_MODEL_CONTROL = yes;
            ARM64_ACTLR_STATE = yes;

            # Might lead to the machine rebooting if not loaded soon enough
            APPLE_WATCHDOG = yes;

            # Can not be built as a module, defaults to no
            APPLE_M1_CPU_PMU = yes;

            # Defaults to 'y', but we want to allow the user to set options in modprobe.d
            HID_APPLE = module;

            APPLE_PMGR_MISC = yes;
            APPLE_PMGR_PWRSTATE = yes;

            # Defaults to 'n', but needed to prevent bluetooth stuttering
            BT_BRCMEXT = yes;
          };
          features.rust = true;
        }
        {
          # Touch ID / Secure Enclave. Mirrors nixos-aurora's kernel/common.config
          # and the driver's Kconfig dependencies (RUST, HW_RANDOM, TRUSTED_KEYS,
          # CRYPTO). The driver refuses to compile without CONFIG_OF_DYNAMIC,
          # which is not user-selectable: OF_OVERLAY selects it.
          name = "Apple SEP (Touch ID)";
          patch = null;
          structuredExtraConfig = with lib.kernel; {
            APPLE_SEP = module;
            SPI_APPLE = module; # Mesa sensor sits on spi2
            HW_RANDOM = yes;
            KEYS = yes;
            TRUSTED_KEYS = yes;
            OF_OVERLAY = yes; # -> OF_DYNAMIC
          };
        }
        {
          # Per-use Secure Enclave keys for a passkey authenticator (linux-passkey's SEP
          # backend): SEP_BIO_KEY_CREATE / SEP_BIO_KEY_SIGN on their own node, /dev/sep-key,
          # so a group can use them without access to Touch ID (/dev/sep-bio). Reuses the
          # driver's ref-key create (op "oc") and sign (op "osgn"). Also logs every xART
          # write (key operations cause none).
          name = "apple-sep-key-ioctls";
          patch = ./apple-sep-key-ioctls.patch;
        }
      ]
      ++ _kernelPatches;
    };

  linux-asahi = callPackage linux-asahi-pkg { };
in
lib.recurseIntoAttrs (linuxPackagesFor linux-asahi)
