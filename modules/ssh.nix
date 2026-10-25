# SSH between my machines (herdr's saved machines, plain ssh), over Tailscale only.
#
# The firewall is off (base.nix), so sshd itself only lets andrew in from Tailscale
# addresses; a connection from the LAN or the internet is refused before authentication.
# Keys only, no root. On a fresh machine: sign Tailscale in, then `ssh nixPC` / `ssh nixAir`.
{ ... }:

let
  # ~/.ssh/id_ed25519.pub (the same key nixvps accepts).
  andrewKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOBNgSP/ZOH+K/xITHoFBxXcf2ykz60GEztt/YXsP6tH andrzej1_1@o2.pl";
in
{
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      # Tailscale's CGNAT range and its IPv6 prefix.
      AllowUsers = [ "andrew@100.64.0.0/10" "andrew@fd7a:115c:a1e0::/48" ];
    };
    # Host key on /persist: / is rolled back on every boot, and a new host key each time
    # would make ssh (and herdr) refuse the machine as changed. Generated on first start.
    hostKeys = [
      { type = "ed25519"; path = "/persist/etc/ssh/ssh_host_ed25519_key"; }
    ];
  };

  users.users.andrew.openssh.authorizedKeys.keys = [ andrewKey ];

  # My machines by name, for ssh and `herdr machine add`: the laptop and the workstation by
  # their Tailscale (MagicDNS) names, the VPS (not on the tailnet) by its public address.
  programs.ssh.extraConfig = ''
    Host nixPC nixpc
      HostName nixpc
    Host nixAir nixair
      HostName nixair
    Host nixvps
      HostName 152.53.157.65
    Host nixPC nixpc nixAir nixair nixvps
      User andrew
      IdentityFile ~/.ssh/id_ed25519
  '';
}
