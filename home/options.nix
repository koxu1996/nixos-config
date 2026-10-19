# options.nix — per-host knobs for the shared Home Manager config.
{ lib, ... }:

{
  options.my.hyprland.mainMod = lib.mkOption {
    type = lib.types.enum [ "ALT" "SUPER" ];
    default = "ALT";
    description = ''
      Main Hyprland modifier. The other of ALT/SUPER becomes the secondary
      modifier (lock screen etc.).
    '';
  };

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
