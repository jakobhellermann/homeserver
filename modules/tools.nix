{ pkgs, ... }:

let
  diff-system = pkgs.writeShellScriptBin "diff-system" ''
    printf '%s\n' /nix/var/nix/profiles/system-*-link | sort -V | \
      awk -F'[-/]' '{print $0 "\t" $(NF-1)}' | ${pkgs.fzf}/bin/fzf --tac \
      --with-nth 2 \
      --preview='
        current={1}
        num=$(basename "$current" | grep -oP "\d+")
        prev="/nix/var/nix/profiles/system-$((num-1))-link"
        echo "$prev" "$current"
        if [[ -e "$prev" ]]; then
          CLICOLOR_FORCE=1 ${pkgs.dix}/bin/dix "$prev" "$current"
        else
          echo "No previous generation"
        fi
      ' \
      --no-border --preview-window=right:90%:noborder
  '';
in

{
  environment.systemPackages = with pkgs; [
    binutils
    curl
    diff-system
    dig
    dix
    dust
    eza
    fd
    fish
    git
    htop
    jq
    jujutsu
    lshw
    ncdu
    neovim
    nix-tree
    pciutils
    ripgrep
    smartmontools
    tcpdump
    tmux
  ];

  environment.variables.EDITOR = "nvim";

  programs.command-not-found.enable = false;
  programs.nix-index.enableBashIntegration = false;
  programs.nix-index-database.comma.enable = true;

  programs.fish.enable = true;
  programs.fish.shellAliases = {
    "vim" = "nvim";
    "ls" = "eza";
    "lt" = "eza --tree";
  };
  programs.fish.interactiveShellInit = ''
    set fish_greeting
    set fish_key_bindings fish_hybrid_key_bindings
    function fish_mode_prompt; end

    function fish_prompt
      set -l last_status $status
      if test (id -u) -eq 0
        set color magenta
      else if test $last_status -gt 0
        set color red
      else
        set color yellow
      end
      set pwd (realpath --relative-base ~ (pwd) \
             | string replace -r '^\.$' '~' \
             | string split '/' | tail -n 3 | string join '/')
      set -l path_color (test (id -u) -eq 0 && echo magenta || echo yellow)
      echo -n (set_color $path_color) $pwd (set_color $color)'mel' (set_color normal)
    end
  '';
  programs.bash = {
    interactiveShellInit = ''
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
      then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };
}
