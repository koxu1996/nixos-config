{
  description = "A simple NixOS flake";

  inputs = {
    # NixOS official package source, using the latest versions.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Frytak's TBSM.
    tbsm.url = "github:Frytak/NixFlake-TBSM";
    tbsm.inputs.nixpkgs.follows = "nixpkgs";
    # Home Manager.
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # Impermanence.
    impermanence.url = "github:nix-community/impermanence";
    # Dynamic cursor.
    #hypr-dynamic-cursors
    # Custom Hy3, because pkgs.hyprlandPlugins.hy3 seems to be broken...
    hy3 = {
      url = "github:outfoxxed/hy3?ref=hl0.52.0";
    };
  };

  outputs = { self, nixpkgs, tbsm, hy3, home-manager, impermanence, ... }@inputs: {
    # nixPC is the hostname.
    nixosConfigurations.nixPC = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        impermanence.nixosModules.impermanence
        ./configuration.nix
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
          home-manager.users.andrew = import ./home.nix;

          # Pass extra arguments to home.nix
          home-manager.extraSpecialArgs = {
            inherit tbsm hy3;
          };
        }
      ];
    };

    # Include formatter, so we can run `nix fmt`.
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
  };
}
