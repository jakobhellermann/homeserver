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
}
