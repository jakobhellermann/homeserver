{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    curl
    fish
    git
    htop
    jq
    jujutsu
    ncdu
    neovim
    nix-tree
    ripgrep
  ];

  environment.variables.EDITOR = "nvim";

  programs.command-not-found.enable = false;
  programs.nix-index.enableBashIntegration = false;
  programs.nix-index-database.comma.enable = true;
}
