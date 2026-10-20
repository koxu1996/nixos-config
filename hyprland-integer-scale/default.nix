# Hyprland patch for integer output scales (nixAir's panel runs at scale 2).
#
# A tiled window narrower than the client's minimum size gets a buffer bigger than its
# tile. Hyprland crops such buffers, except on scaled outputs, where it treats every
# buffer-scale-N surface as "scale unaware" and squishes the whole buffer into the tile
# instead: the window looks distorted and clicks land in the wrong place (pointer input
# still maps 1:1). The patch limits that special case to fractional scales, where it
# came from; at an integer scale the buffer maps 1:1, so it is cropped like at scale 1.
#
# Still present on Hyprland main (2026-10); drop this once fixed upstream.
{ ... }:
{
  nixpkgs.overlays = [
    (final: prev: {
      hyprland = prev.hyprland.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./hyprland-0.56.2-integer-scale-crop.patch ];
      });
    })
  ];
}
