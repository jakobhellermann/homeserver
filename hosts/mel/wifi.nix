{ config, ... }:

{
  networking.networkmanager = {
    enable = true;
    ensureProfiles.environmentFiles = [ config.age.secrets.wifi-password-env.path ];
    ensureProfiles.profiles = {
      home-wifi = {
        connection = {
          id = "home-wifi";
          type = "wifi";
        };
        wifi = {
          mode = "infrastructure";
          ssid = "FRITZ!Box 6660 Cable TO";
        };
        wifi-security = {
          auth-alg = "open";
          key-mgmt = "wpa-psk";
          psk = "$WIFI_PASSWORD_FRITZBOX";
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };
    };
  };
}
