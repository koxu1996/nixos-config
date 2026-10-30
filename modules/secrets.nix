# Secrets via sops-nix, kept out of this public repo.
#
# The encrypted file lives in the Syncthing folder (~/Sync/nix-secrets/secrets.yaml),
# so it reaches both machines without Git or any third party; this config only names
# the secrets. Each host decrypts it at activation with its SSH host key
# (/persist/etc/ssh, modules/ssh.nix), and I edit it with my own ~/.ssh/id_ed25519.
# The recipients are listed in ~/Sync/nix-secrets/.sops.yaml.
#
#   nix-secrets              edit (re-encrypts on save, Syncthing carries it over)
#   nixos-rebuild switch     a host picks the change up (or on the next boot)
#
# New host: add its key (`ssh-to-age < /persist/etc/ssh/ssh_host_ed25519_key.pub`) to
# .sops.yaml, then `nix-secrets updatekeys`.
{ pkgs, ... }:

let
  dir = "/persist/home/andrew/Sync/nix-secrets";
in
{
  sops = {
    # A runtime path, not a Nix path: the file never enters the store or this repo.
    defaultSopsFile = "${dir}/secrets.yaml";
    validateSopsFiles = false;
    age.sshKeyPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
    gnupg.sshKeyPaths = [ ];

    # Decrypted before users are created (hashedPasswordFile in base.nix).
    secrets.andrew-password.neededForUsers = true;
  };

  environment.systemPackages = [
    # sops finds .sops.yaml from the working directory, hence the cd.
    (pkgs.writeShellScriptBin "nix-secrets" ''
      cd ${dir} || exit 1
      # The recipients are age keys converted from SSH keys (as sops-nix does for the
      # host keys), so convert mine the same way rather than using sops' native SSH mode.
      export SOPS_AGE_KEY_CMD="${pkgs.ssh-to-age}/bin/ssh-to-age -private-key -i $HOME/.ssh/id_ed25519"
      if [ "$1" = updatekeys ]; then
        exec ${pkgs.sops}/bin/sops updatekeys secrets.yaml
      fi
      exec ${pkgs.sops}/bin/sops "''${@:-secrets.yaml}"
    '')
  ];
}
