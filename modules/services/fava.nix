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
    githubTokenFile = mkOption {
      type = types.nullOr types.path;
      default = null;
    };
    beancountFile = mkOption {
      type = types.str;
      default = "journal.beancount";
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/fava";
    };
    sshKeyFile = mkOption {
      type = types.path;
      default = "/root/.ssh/id_ed25519";
    };
    nginx.subdomain = mkOption { type = types.str; };
  };

  config = mkIf cfg.enable {
    systemd.services.fava = {
      description = "Fava Beancount Web Interface";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      path = [
        pkgs.git
        pkgs.gcc
        pkgs.stdenv.cc.cc.lib
        pkgs.nodejs
      ];
      environment = {
        GIT_SSH_COMMAND = "${pkgs.openssh}/bin/ssh -i ${cfg.sshKeyFile} -o StrictHostKeyChecking=accept-new";
        LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";
        UV_PYTHON_PREFERENCE = "only-system";
      };

      serviceConfig = {
        Type = "simple";
        WorkingDirectory = cfg.dataDir;
        ExecStartPre = pkgs.writeShellScript "fava-setup" ''
          set -e

          # Create data directory if it doesn't exist
          mkdir -p ${cfg.dataDir}

          # Clone or update repository
          if [ -d ${cfg.dataDir}/.git ]; then
            echo "Updating existing repository..."
            cd ${cfg.dataDir}
            ${pkgs.git}/bin/git fetch origin
            ${pkgs.git}/bin/git reset --hard origin/main || ${pkgs.git}/bin/git reset --hard origin/master
          else
            echo "Cloning repository..."
            ${pkgs.git}/bin/git clone ${cfg.repoUrl} ${cfg.dataDir}
          fi
        '';
        ExecStart = "${pkgs.uv}/bin/uv run --python ${pkgs.python3}/bin/python3 fava ${cfg.beancountFile} --host 127.0.0.1 --port ${toString cfg.port}";
        Restart = "always";
        RestartSec = "10s";

        # Run as root to access SSH keys
        # (Alternative: copy key to service-owned location)
        User = "root";
        StateDirectory = "fava";

        # Allow network access
        PrivateNetwork = false;
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
