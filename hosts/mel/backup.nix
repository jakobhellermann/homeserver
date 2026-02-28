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

  services.restic.backups."paperless" = {
    inherit passwordFile;
    inherit environmentFile;
    inherit timerConfig;
    inherit repository;

    paths = [ "/persist/services/var/lib/paperless" ];
    extraBackupArgs = retryLock ++ [
      "--tag paperless"
      "--tag service"
    ];

    pruneOpts = retryLock ++ [
      "--keep-daily 14"
      "--keep-weekly 4"
      "--keep-monthly 2"
      "--group-by tags"
    ];
  };
  services.restic.backups."paperless-postgres" = {
    inherit passwordFile;
    inherit environmentFile;
    inherit timerConfig;
    inherit repository;

    initialize = true;

    command = [
      "${lib.getExe pkgs.sudo}"
      "-u postgres"
      "${pkgs.postgresql}/bin/pg_dump"
      "--clean"
      "paperless"
    ];
    extraBackupArgs = retryLock ++ [
      "--tag paperless"
      "--tag db"
      "--stdin-filename paperless.sql"
    ];

    pruneOpts = retryLock ++ [
      "--keep-daily 14"
      "--keep-weekly 4"
      "--keep-monthly 2"
      "--group-by tags"
    ];
  };

  services.restic.backups."immich" = {
    inherit passwordFile;
    inherit environmentFile;
    inherit timerConfig;
    inherit repository;

    paths = [
      "/persist/services/var/lib/immich/library"
      "/persist/services/var/lib/immich/upload"
      "/persist/services/var/lib/immich/profile"
    ];
    extraBackupArgs = retryLock ++ [
      "--tag immich"
      "--tag service"
    ];

    pruneOpts = retryLock ++ [
      "--keep-daily 14"
      "--keep-weekly 4"
      "--keep-monthly 2"
      "--group-by tags"
    ];
  };
  services.restic.backups."immich-postgres" = {
    inherit passwordFile;
    inherit environmentFile;
    inherit timerConfig;
    inherit repository;

    initialize = true;

    command = [
      "${lib.getExe pkgs.sudo}"
      "-u postgres"
      "${pkgs.postgresql}/bin/pg_dump"
      "--clean"
      "immich"
    ];
    extraBackupArgs = retryLock ++ [
      "--tag immich"
      "--tag db"
      "--stdin-filename immich.sql"
    ];

    pruneOpts = retryLock ++ [
      "--keep-daily 14"
      "--keep-weekly 4"
      "--keep-monthly 2"
      "--group-by tags"
    ];
  };
}
