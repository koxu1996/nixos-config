# Userspace glue for the apple_sep kernel driver: loader, readiness check,
# per-device Mesa calibration extraction, sensor presence probe.
#
# Vendored from aurora-silicon/nixos-aurora `sep/` (itself derived from
# tools/aurora-sep in aurora-silicon/linux, see provenance.json). Local
# changes, both marked "nixAir" in the scripts:
#   - load-driver: TOUCHID_XART_WRITES=0 loads the driver read-only and skips
#     the trusted-key probe (which needs a provisioned keybag).
#   - prepare-sep-calibration: writes the blob to /lib/firmware (kernel fallback
#     search path) instead of firmware_class.path, which on NixOS is the
#     read-only Nix store.
{ stdenvNoCC, lib, makeWrapper, bash, coreutils, keyutils, kmod, python3, util-linux, gnugrep }:
stdenvNoCC.mkDerivation {
  pname = "aurora-sep";
  version = "1.5-nixair";
  src = ./.;
  nativeBuildInputs = [ makeWrapper python3 bash ];
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 load-driver $out/libexec/aurora-sep-load
    install -Dm755 aurora-sep-ready $out/libexec/aurora-sep-ready
    for helper in prepare-sep-calibration extract-mesa-calibration sensor-present; do
      install -Dm755 "$helper" "$out/libexec/aurora/$helper"
    done
    substituteInPlace $out/libexec/aurora/prepare-sep-calibration \
      --replace-fail /usr/libexec/aurora/extract-mesa-calibration $out/libexec/aurora/extract-mesa-calibration
    patchShebangs $out/libexec
    for helper in $out/libexec/aurora-sep-* $out/libexec/aurora/prepare-sep-calibration $out/libexec/aurora/sensor-present; do
      wrapProgram "$helper" --prefix PATH : ${lib.makeBinPath [ bash coreutils keyutils kmod util-linux gnugrep ]}
    done
    install -Dm644 README.md $out/share/doc/aurora-sep/README.md
    install -Dm644 XART-SAFETY.md $out/share/doc/aurora-sep/XART-SAFETY.md
    runHook postInstall
  '';
  meta.license = lib.licenses.gpl2Only;
}
