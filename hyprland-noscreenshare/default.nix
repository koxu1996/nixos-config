# Hyprland with the "transparent noscreenshare" patch, plus a live demo.
#
# The patch keeps layer-shell surfaces that have the no_screen_share layer rule
# out of screen shares entirely: sharers (OBS, browsers, grim) see the content
# behind them instead of Hyprland's usual black box. Source and notes:
# ~/Downloads/tmp/clutch/patches (hyprland-0.56.2-transparent-noscreenshare.patch).
#
# The patch targets Hyprland 0.56.2 as packaged in nixpkgs; it stops applying
# once nixpkgs moves past 0.56.x (switch to the patch for Hyprland main then).
#
# Demo: run `noscreenshare-demo` from a terminal in a Hyprland session and share
# the screen (e.g. webrtc-experiment.com). Needs the layer rule for
# namespace "noscreenshare-demo" (see hyprland.nix).
{ pkgs, ... }:
let
  noscreenshare-demo = pkgs.python3Packages.buildPythonApplication {
    pname = "noscreenshare-demo";
    version = "1";
    format = "other";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.wrapGAppsHook3 pkgs.gobject-introspection ];
    buildInputs = [ pkgs.gtk3 pkgs.gtk-layer-shell ];
    dependencies = [ pkgs.python3Packages.pygobject3 pkgs.python3Packages.pycairo ];
    installPhase = ''
      install -Dm755 ${./demo.py} $out/bin/noscreenshare-demo
    '';
    dontWrapGApps = true;
    preFixup = ''
      makeWrapperArgs+=("''${gappsWrapperArgs[@]}")
    '';
  };
in
{
  nixpkgs.overlays = [
    (final: prev: {
      hyprland = prev.hyprland.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./hyprland-0.56.2-transparent-noscreenshare.patch ];
      });
    })
  ];

  environment.systemPackages = [ noscreenshare-demo ];
}
