# Thunderbird email client, pre-configured for the Brosoft mail server
# (docker-mailserver running on the VPS).
#
# Enabling this installs Thunderbird AND declaratively creates the
# kontakt@brosoft.xyz account via home-manager's `accounts.email` module, so
# receiving mail works on first launch. home-manager does NOT store the
# password - Thunderbird prompts for it once and keeps it in its own password
# store.
#
# Server settings (see the VPS docker-mailserver):
#   IMAP  mail.brosoft.xyz : 993   implicit TLS (SSL/TLS)   -> receiving
#   SMTP  mail.brosoft.xyz : 465   implicit TLS (SSL/TLS)   -> sending
# The TLS cert is *.brosoft.xyz, so the server name must be mail.brosoft.xyz
# (matches the cert; no security exception needed).
{ ... }:

{
  programs.thunderbird = {
    enable = true;
    # A default profile is required; accounts below are attached to it.
    profiles.andrew.isDefault = true;
  };

  accounts.email.accounts."brosoft-xyz" = {
    primary = true;
    address = "kontakt@brosoft.xyz";
    userName = "kontakt@brosoft.xyz"; # the full address is the login name
    realName = "Andrzej"; # sender display name - edit to taste

    # Receiving.
    imap = {
      host = "mail.brosoft.xyz";
      port = 993;
      tls.enable = true; # implicit TLS (SSL/TLS), not STARTTLS
    };

    # Sending.
    smtp = {
      host = "mail.brosoft.xyz";
      port = 465;
      tls.enable = true; # implicit TLS (SSL/TLS)
    };

    # Attach this account to the Thunderbird profile(s) defined above.
    thunderbird.enable = true;
  };

  # DEPRECATED / TEMPORARY: kontakt@brosoft.pro.
  # The brosoft.pro domain is being retired - its TLS cert renewal is already
  # disabled on the VPS (only brosoft.xyz auto-renews now), and the domain
  # itself is slated for removal. This account still works for now (the mailbox
  # lives on the same server and we connect via mail.brosoft.xyz, so the
  # *.brosoft.xyz cert still applies), but expect it to stop receiving mail once
  # brosoft.pro is dropped. Remove this block when that happens.
  accounts.email.accounts."brosoft-pro" = {
    address = "kontakt@brosoft.pro";
    userName = "kontakt@brosoft.pro"; # the full address is the login name
    realName = "Andrzej";

    # Same physical server as brosoft.xyz; hostname stays mail.brosoft.xyz so
    # the presented *.brosoft.xyz cert validates (there is no valid pro cert).
    imap = {
      host = "mail.brosoft.xyz";
      port = 993;
      tls.enable = true; # implicit TLS (SSL/TLS)
    };

    smtp = {
      host = "mail.brosoft.xyz";
      port = 465;
      tls.enable = true; # implicit TLS (SSL/TLS)
    };

    thunderbird.enable = true;
  };
}
