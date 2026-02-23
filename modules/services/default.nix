{ lib, ... }:

{
  options.my.services = lib.mkOption { };

  options.my.domains = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    description = "List of base domains for services (e.g., mel.local, mel.home)";
  };
}
