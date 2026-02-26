{
  description = "homeserver config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    agenix.url = "github:ryantm/agenix";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    impermanence.url = "github:nix-community/impermanence";
    impermanence.inputs.nixpkgs.follows = "nixpkgs";
    impermanence.inputs.home-manager.follows = "";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ nixpkgs, ... }:
    let
      sharedModules = [
        inputs.disko.nixosModules.disko
        inputs.nix-index-database.nixosModules.nix-index
        inputs.impermanence.nixosModules.impermanence
        inputs.agenix.nixosModules.default
      ];
    in
    {
      nixosConfigurations.mel = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = sharedModules ++ [
          ./hosts/mel/configuration.nix
          {
            nixpkgs.overlays = [
              (final: prev: {
                paperless-ngx = prev.paperless-ngx.overrideAttrs (_: {
                  dontUsePytestCheck = true;
                });
              })
            ];
          }
        ];
      };
    };
}
