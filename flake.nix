{
  description = "A simple NixOS flake";

  inputs = {
    # NixOS official package source, using the latest versions.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # TBSM (session launcher).
    tbsm.url = "github:koxu1996/tbsm/add-nix-flake";
    tbsm.inputs.nixpkgs.follows = "nixpkgs";
    # Home Manager.
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # Impermanence.
    impermanence.url = "github:nix-community/impermanence";
    # Disko - declarative disk partitioning / ZFS layout.
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    # clutch HUD — private GitLab repo (app source stays private; only the glue
    # in this public config + the hyprland-noscreenshare patch are public).
    clutch.url = "git+ssh://git@gitlab.com/andrzej1_1/clutch";
    clutch.inputs.nixpkgs.follows = "nixpkgs";
    # linux-passkey (ex tpm2-passkey) — hardware-backed FIDO2 passkey authenticator:
    # TPM on nixPC, Secure Enclave + fingerprint on nixAir.
    linux-passkey.url = "github:koxu1996/linux-passkey";
    linux-passkey.inputs.nixpkgs.follows = "nixpkgs";
    # Apple Silicon (Asahi) kernel, firmware and boot support for nixAir.
    nixos-apple-silicon.url = "github:nix-community/nixos-apple-silicon";
    nixos-apple-silicon.inputs.nixpkgs.follows = "nixpkgs";
    # Dynamic cursor.
    #hypr-dynamic-cursors
  };

  outputs = { self, nixpkgs, tbsm, home-manager, impermanence, disko, nixos-apple-silicon, clutch, linux-passkey, ... }@inputs:
    let
      # One NixOS system per host. `modules` are the host's own modules (they
      # import ./modules/base.nix themselves where order matters); everything
      # else here is shared by all hosts.
      mkHost = { system, modules }: nixpkgs.lib.nixosSystem {
        modules = [
          { nixpkgs.hostPlatform = system; }
          impermanence.nixosModules.impermanence
          disko.nixosModules.disko
        ] ++ modules ++ [
          tbsm.nixosModules.tbsm
          {
            tbsm = {
              enable = true;
              autoStart = {
                enable = true;
                allowedTtys = [ "/dev/tty1" ];
              };
              config = ''
                #XserverArg="-quiet -nolisten tcp"
                verboseLevel=2 # info level
                theme=""
              '';
            };
          }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.andrew = import ./home;

            # Pass extra arguments to home/default.nix
            home-manager.extraSpecialArgs = {
              inherit tbsm clutch;
            };
          }
        ];
      };
    in
    {
    # nixPC is the hostname.
    nixosConfigurations.nixPC = mkHost {
      system = "x86_64-linux";
      modules = [
        ./hosts/nixPC/disko.nix
        linux-passkey.nixosModules.default
        ./hosts/nixPC/tpm.nix
        ./modules/base.nix
        ./hosts/nixPC
        # Patched Hyprland (no_screen_share layers hidden from shares) + demo.
        ./hyprland-noscreenshare
      ];
    };

    # nixAir: MacBook Air M2 (Apple Silicon). Build with --impure (firmware).
    nixosConfigurations.nixAir = mkHost {
      system = "aarch64-linux";
      modules = [
        nixos-apple-silicon.nixosModules.apple-silicon-support
        ./hosts/nixAir/disko.nix
        ./modules/base.nix
        # Hyprland: crop oversized windows at scale 2 instead of squishing them.
        ./hyprland-integer-scale
        # Passkeys in the Secure Enclave (services.linux-passkey in hosts/nixAir).
        linux-passkey.nixosModules.default
        # Patched Hyprland (no_screen_share layers hidden from shares) + demo.
        ./hyprland-noscreenshare
        ./hosts/nixAir
      ];
    };

    # Installer for nixAir: nixos-apple-silicon's installer ISO plus ZFS, on the
    # same nixpkgs (so the same Asahi kernel and ZFS) as nixAir itself. The
    # official ISO has ZFS switched off. Build:
    #   nix build --option builders "" .#installer-nixAir -o result-installer
    packages.aarch64-linux.installer-nixAir =
      let
        installer = nixpkgs.lib.nixosSystem {
          modules = [
            nixos-apple-silicon.nixosModules.apple-silicon-installer
            ({ lib, ... }: {
              nixpkgs.hostPlatform = "aarch64-linux";
              boot.supportedFilesystems.zfs = lib.mkForce true;
              networking.hostId = "a35dc981"; # nixAir's, so the pool imports cleanly.
              environment.systemPackages = [ disko.packages.aarch64-linux.default ];
            })
          ];
        };
      in
      installer.config.system.build.isoImage.overrideAttrs (old: {
        passthru = (old.passthru or { }) // { inherit (installer) config; };
      });

    # Include formatter, so we can run `nix fmt`.
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
  };
}
