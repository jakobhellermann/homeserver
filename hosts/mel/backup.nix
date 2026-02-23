{
  pkgs,
  lib,
  config,
  ...
}:

let
  passwordFile = config.age.secrets.restic-password.path;
  environmentFile = config.age.secrets.restic-env.path;
  repository = "/persist/backup";

  timerConfig = {
    OnCalendar = "*-*-* 02:00:00";
    Persistent = true;
  };

  retryLock = [
    "--retry-lock 5m"
  ];
in
{
  environment.systemPackages = [ pkgs.restic ];

  environment.variables = {
    RESTIC_PASSWORD_FILE = passwordFile;
    RESTIC_REPOSITORY = repository;
  };

  programs.fish.interactiveShellInit = ''
    function restic --wraps=restic
      sudo --preserve-env=RESTIC_PASSWORD_FILE,RESTIC_REPOSITORY ${lib.getExe pkgs.restic} $argv
    end
  '';

  services.restic.backups."homeassistant" = {
    inherit passwordFile;
    inherit environmentFile;
    inherit timerConfig;
    inherit repository;

    paths = [ "/persist/services/var/lib/homeassistant" ];
    extraBackupArgs = retryLock ++ [
      "--tag service"
      "--tag homeassistant"
    ];

    pruneOpts = retryLock ++ [
      "--keep-daily 14"
      "--keep-weekly 4"
      "--keep-monthly 2"
      "--group-by tags"
    ];
  };
}
