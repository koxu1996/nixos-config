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
    # sops-nix - decrypts secrets at activation. The encrypted file is not in this
    # repo: it lives in ~/Sync/nix-secrets (see modules/secrets.nix).
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    # Disko - declarative disk partitioning / ZFS layout.
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    # clutch HUD — private GitHub repo (app source stays private; only the glue
    # in this public config + the hyprland-noscreenshare patch are public).
    clutch.url = "git+ssh://git@github.com/koxu1996/clutch";
    clutch.inputs.nixpkgs.follows = "nixpkgs";
    # linux-passkey (ex tpm2-passkey) — hardware-backed FIDO2 passkey authenticator:
    # TPM on nixPC, Secure Enclave + fingerprint on nixAir.
    linux-passkey.url = "github:koxu1996/linux-passkey";
    linux-passkey.inputs.nixpkgs.follows = "nixpkgs";
    # pkee — fingerprint-unlocked KeePass launcher (home/pkee.nix).
    pkee.url = "github:koxu1996/pkee";
    pkee.inputs.nixpkgs.follows = "nixpkgs";
    # Apple Silicon (Asahi) kernel, firmware and boot support for nixAir.
    nixos-apple-silicon.url = "github:nix-community/nixos-apple-silicon";
    nixos-apple-silicon.inputs.nixpkgs.follows = "nixpkgs";
    # Dynamic cursor.
    #hypr-dynamic-cursors
  };

  outputs = { self, nixpkgs, tbsm, home-manager, impermanence, disko, sops-nix, nixos-apple-silicon, clutch, linux-passkey, pkee, ... }@inputs:
    let
      # One NixOS system per host. `modules` are the host's own modules (they
      # import ./modules/base.nix themselves where order matters); everything
      # else here is shared by all hosts.
      mkHost = { system, modules }: nixpkgs.lib.nixosSystem {
        modules = [
          { nixpkgs.hostPlatform = system; }
          impermanence.nixosModules.impermanence
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          ./modules/secrets.nix
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
            home-manager.sharedModules = [ pkee.homeManagerModules.default ];

            # Pass extra arguments to home/default.nix
            home-manager.extraSpecialArgs = {
              inherit tbsm clutch linux-passkey;
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
        ./modules/ssh.nix # SSH between my machines, Tailscale only.
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
        ./modules/ssh.nix # SSH between my machines, Tailscale only.
        # Hyprland: crop oversized windows at scale 2 instead of squishing them.
        ./hyprland-integer-scale
        # Passkeys in the Secure Enclave (services.linux-passkey in hosts/nixAir).
        linux-passkey.nixosModules.default
        # Patched Hyprland (no_screen_share layers hidden from shares) + demo.
        ./hyprland-noscreenshare
        ./hosts/nixAir
      ];
    };

    # nuc: headless home server (Intel NUC). No desktop, so not mkHost.
    # Installed with nixos-anywhere (hosts/nuc/README.md).
    nixosConfigurations.nuc = nixpkgs.lib.nixosSystem {
      modules = [
        { nixpkgs.hostPlatform = "x86_64-linux"; }
        impermanence.nixosModules.impermanence
        disko.nixosModules.disko
        ./modules/ssh.nix
        ./hosts/nuc
      ];
    };

    # nixvps: VPS with the RKE2 cluster and cocoon. Deployed remotely
    # (hosts/nixvps/default.nix).
    nixosConfigurations.nixvps = nixpkgs.lib.nixosSystem {
      modules = [ ./hosts/nixvps ];
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
