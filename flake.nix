{
  description = "Flake-based NixOS config for homelab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Secrets are committed encrypted and unlocked by the host at boot.
    # Deliberately NOT set to follow our nixpkgs: sops-nix tracks unstable and
    # its helper needs a newer Go than nixos-25.05 ships.
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, flake-utils, sops-nix, ... }:
  let
    system = "x86_64-linux";
    overlay-unstable = final: prev: {
      unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    };
  in {
    nixosConfigurations.homelab = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ({ ... }: { nixpkgs.overlays = [ overlay-unstable ]; })
        sops-nix.nixosModules.sops
        # Build the secrets helper from sops-nix's own nixpkgs, not ours.
        { sops.package = sops-nix.packages.${system}.sops-install-secrets; }
        ./hosts/homelab/configuration.nix
      ];
    };

    nixosConfigurations.homelab_zfs = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ({ ... }: { nixpkgs.overlays = [ overlay-unstable ]; })
        ./hosts/homelab_zfs/configuration.nix
      ];
    };
  };
}
