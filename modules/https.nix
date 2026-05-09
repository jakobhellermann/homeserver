{ config, lib, ... }:

{
  options.my.https.acmeEmail = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Email for ACME/Let's Encrypt registration. ACME is enabled when this is set.";
  };

  config = lib.mkIf (config.my.https.acmeEmail != null) {
    security.acme = {
      acceptTerms = true;
      defaults.email = config.my.https.acmeEmail;
    };
  };
}
