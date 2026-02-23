{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.fava;
in
{
  options.services.fava = {
    enable = mkEnableOption "Fava beancount web interface";
    port = mkOption { type = types.port; };
    repoUrl = mkOption { type = types.str; };
    beancountFile = mkOption { type = types.str; };
    sshKeyFile = mkOption { type = types.path; };
    nginx.subdomain = mkOption { type = types.str; };
  };

  config = mkIf cfg.enable {
    systemd.services.fava = {
      description = "Fava Beancount Web Interface";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      startLimitIntervalSec = 60;

      path = [
        pkgs.git
        pkgs.gcc
        pkgs.stdenv.cc.cc.lib
        pkgs.nodejs
      ];
      environment = {
        GIT_SSH_COMMAND = "${pkgs.openssh}/bin/ssh -i $CREDENTIALS_DIRECTORY/ssh-key -o StrictHostKeyChecking=accept-new";
        LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";
        UV_PYTHON_PREFERENCE = "only-system";
      };

      serviceConfig = {
        Type = "simple";
        StateDirectory = "fava";
        CacheDirectory = "fava";
        WorkingDirectory = "%S/fava";
        Environment = "UV_CACHE_DIR=%C/fava";
        ExecStartPre = pkgs.writeShellScript "fava-setup" ''
          set -e

          # Clone or update repository
          if [ -d .git ]; then
            echo "Updating existing repository..."
            ${pkgs.git}/bin/git fetch origin
            ${pkgs.git}/bin/git reset --hard origin/main || ${pkgs.git}/bin/git reset --hard origin/master
          else
            echo "Cloning repository..."
            ${pkgs.git}/bin/git clone ${cfg.repoUrl} .
          fi
        '';
        ExecStart = "${pkgs.uv}/bin/uv run --python ${pkgs.python3}/bin/python3 fava ${cfg.beancountFile} --host 127.0.0.1 --port ${toString cfg.port}";
        Restart = "on-failure";
        RestartSec = "10s";
        StartLimitBurst = 3;

        LoadCredential = "ssh-key:${cfg.sshKeyFile}";

        User = "root";
      };
    };

    # Ensure git and uv are available
    environment.systemPackages = with pkgs; [
      git
      uv
    ];

    services.nginx.virtualHosts."${cfg.nginx.subdomain}" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.port}";
      };
    };
  };
}
