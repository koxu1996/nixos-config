# gitkay: "gitk, but okay" - a native Wayland git history viewer (Rust, egui/eframe on
# OpenGL, libgit2). Not in nixpkgs; https://github.com/Marenz/gitkay
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  zlib,
  makeWrapper,
  wayland,
  libxkbcommon,
  libGL,
  xorg,
}:

rustPlatform.buildRustPackage {
  pname = "gitkay";
  version = "1.2.0-unstable-2026-06-24";

  src = fetchFromGitHub {
    owner = "Marenz";
    repo = "gitkay";
    rev = "d97146302caa9a9a50a8754078de0a17b9271f69";
    hash = "sha256-eqzPqWYkEUB6JuAUIy2ljFsNGwwtQ3VcS9p9WUBiQ2U=";
  };

  cargoHash = "sha256-nMW+dnT0mTtGyOfGzQnW166W2bW2YYiKyLDWAwLD00Q=";

  nativeBuildInputs = [ pkg-config makeWrapper ];
  # git2 0.19 wants libgit2 1.8 (nixpkgs has 1.9), so it builds its bundled copy.
  buildInputs = [ openssl zlib ];

  # winit and glutin dlopen the Wayland, xkbcommon and EGL/GL libraries at runtime (X11 as
  # the fallback), so they have to be findable.
  postFixup = ''
    wrapProgram $out/bin/gitkay \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ wayland libxkbcommon libGL xorg.libX11 xorg.libXcursor xorg.libXi xorg.libXrandr ]}
  '';

  meta = {
    description = "Fast, native Wayland git history viewer - gitk, but okay";
    homepage = "https://github.com/Marenz/gitkay";
    license = lib.licenses.mit;
    mainProgram = "gitkay";
    platforms = lib.platforms.linux;
  };
}
