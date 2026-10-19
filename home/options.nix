# options.nix — per-host knobs for the shared Home Manager config.
{ lib, ... }:

{
  options.my.wallpaper = lib.mkOption {
    type = lib.types.str;
    example = lib.literalExpression ''"''${../wallpapers/space1.jpg}"'';
    description = ''
      Image used by hyprpaper and as the hyprlock background. Every host sets
      it to a file from the repo's wallpapers/ (interpolated, so it lands in
      the store) - no default, so it can never point at a missing file.
    '';
  };
}
