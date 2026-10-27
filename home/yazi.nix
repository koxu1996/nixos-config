# yazi, the terminal file manager, also as the system file chooser: "Open" / "Save as" dialogs
# (browsers and other apps asking the XDG portal) open yazi in a floating Alacritty.
# The portal itself is xdg-desktop-portal-termfilechooser (modules/base.nix).
#
# In the chooser: Enter picks the file under the cursor (Space marks several first);
# q cancels. Saving: termfilechooser puts a placeholder file at the suggested name, so go
# where it should be saved and pick it, or rename it (r) first.
{ pkgs, ... }:

{
  programs.yazi = {
    enable = true;
    # `y`: yazi that cds the shell to the folder it was left in.
    enableZshIntegration = true;
    shellWrapperName = "y";
  };

  # TERMCMD: no quotes or spaces inside an argument (a title like 'Choose a file' arrives as
  # three words; the config reader drops the quotes and alacritty refused the stray "a").
  xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = ''
    [filechooser]
    cmd=${pkgs.xdg-desktop-portal-termfilechooser}/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh
    default_dir=$HOME
    env=TERMCMD=alacritty --class filechooser --title Files -e
    open_mode=suggested
    save_mode=suggested
  '';
}
