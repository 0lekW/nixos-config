{
  description = "Flake-based NixOS config for homelab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, flake-utils, ... }:
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
