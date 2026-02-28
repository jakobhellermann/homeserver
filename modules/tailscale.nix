{ config, lib, ... }:

{
  options.my.tailscale = {
    advertiseRoutes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "192.168.1.0/24"
        "10.0.0.0/8"
      ];
      description = "List of routes to advertise to Tailscale.";
    };
  };

  config = {
    services.tailscale = {
      enable = true;
      authKeyFile = config.age.secrets.tailscale-authkey.path;
      extraUpFlags = lib.optionals (config.my.tailscale.advertiseRoutes != [ ]) [
        "--advertise-routes=${lib.concatStringsSep "," config.my.tailscale.advertiseRoutes}"
      ];
    };
    networking.nftables.enable = true;
    networking.firewall = {
      trustedInterfaces = [ "tailscale0" ];
      allowedUDPPorts = [ config.services.tailscale.port ];
    };

    # 2. Force tailscaled to use nftables over iptables
    systemd.services.tailscaled.serviceConfig.Environment = [
      "TS_DEBUG_FIREWALL_MODE=nftables"
    ];

    # 3. Optimization: Prevent systemd from waiting for network online
    systemd.network.wait-online.enable = false;
    boot.initrd.systemd.network.wait-online.enable = false;
  };
}
