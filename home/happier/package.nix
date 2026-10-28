# Happier: run, watch and steer coding agents (Claude Code, Codex, OpenCode, …) from the
# phone, web or desktop app, end-to-end encrypted through a relay. Not in nixpkgs;
# https://github.com/happier-dev/happier (a fork of Happy).
#
# The release is a Bun single-file binary that loads package-dist/, node_modules/ and
# tools/ from the folder it sits in, so the folder stays whole under lib/happier. Bun keeps
# its payload in an ELF section, so patchelf is safe, but strip is not.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
}:

let
  version = "0.2.17";
  arch = {
    aarch64-linux = { name = "arm64"; hash = "sha256-gOMRDcVaKiLwzKbSaQNxW2dYHrVQm+TkpAO1iYIUu0Q="; };
    x86_64-linux = { name = "x64"; hash = "sha256-lpMo7VKWEZ0Y48pIg54LqvtdBdHtcEevrPusBk/Yy8Q="; };
  }.${stdenv.hostPlatform.system} or (throw "happier: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "happier";
  inherit version;

  src = fetchurl {
    url = "https://github.com/happier-dev/happier/releases/download/cli-v${version}/happier-v${version}-linux-${arch.name}.tar.gz";
    inherit (arch) hash;
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  # node-pty and sharp's native addons.
  buildInputs = [ stdenv.cc.cc.lib ];

  dontStrip = true;

  installPhase = ''
    runHook preInstall
    # musl builds of the native addons can't be patched against glibc and are never loaded.
    find node_modules -name '*musl*' -prune -exec rm -rf {} +
    mkdir -p $out/lib/happier $out/bin
    cp -r . $out/lib/happier
    # Updates come from this file, not `happier self update`.
    makeWrapper $out/lib/happier/happier $out/bin/happier \
      --set-default HAPPIER_CLI_UPDATE_CHECK 0
    runHook postInstall
  '';

  meta = {
    description = "Mobile, web and desktop control for coding agents, end-to-end encrypted";
    homepage = "https://happier.dev";
    license = lib.licenses.mit;
    mainProgram = "happier";
    platforms = [ "aarch64-linux" "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
