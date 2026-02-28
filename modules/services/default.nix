{ lib, ... }:

{
  options.my.services = lib.mkOption { };

  options.my.domains = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    description = "List of base domains for services (e.g., mel.local, mel.home)";
  };
  options.my.localIP = lib.mkOption {
    type = lib.types.str;
    description = "Local IP address of the server on the LAN";
  };
  options.my.tailscaleIP = lib.mkOption {
    type = lib.types.str;
    description = "Tailscale IP address of the server";
  };
}
