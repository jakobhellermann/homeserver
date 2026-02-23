{
  description = "homeserver config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ nixpkgs, ... }:
    let
      sharedModules = [
        inputs.disko.nixosModules.disko
        inputs.nix-index-database.nixosModules.nix-index
      ];
    in
    {
      nixosConfigurations.mel = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = sharedModules ++ [
          ./hosts/mel/configuration.nix
        ];
      };
    };
}
