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
    zmqtt2prom.url = "github:jakobhellermann/zmqtt2prom-rs";
    zmqtt2prom.inputs.nixpkgs.follows = "nixpkgs";
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
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
        specialArgs = { inherit inputs; };
        modules = sharedModules ++ [
          inputs.nix-minecraft.nixosModules.minecraft-servers
          ./hosts/mel/configuration.nix
          {
            nixpkgs.overlays = [
              inputs.nix-minecraft.overlay
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
