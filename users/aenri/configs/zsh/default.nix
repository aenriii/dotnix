{ pkgs, lib, ... }:

{
  home.packages = with pkgs; [ zsh any-nix-shell fastfetch ];
  programs.zsh = {
    enable = true;
    initContent = ''
      # Resolved at shell startup, not at eval time. builtins.getEnv is always
      # "" under flakes' pure evaluation, so the old per-host sourcing never
      # fired -- and doing it at runtime means one closure works on any host.
      dotnix_host=''${HOST:-$(hostname -s 2>/dev/null)}
      for file in ~/.profile ~/.aliases ~/.path; do
        if [[ -f $file ]]; then source $file; fi
        if [[ -f $file.platform ]]; then source $file.platform; fi
        if [[ -n $dotnix_host && -f $file.$dotnix_host ]]; then source $file.$dotnix_host; fi
      done
      unset dotnix_host
      ${lib.readFile ./functions.zsh}
      ${lib.readFile ./prompt.zsh}
      ${pkgs.any-nix-shell}/bin/any-nix-shell zsh --info-right | source /dev/stdin
    '';
    setOptions = [ "PROMPT_SUBST" ];
    plugins = [
      {
        name = "zsh-autosuggestions";
        src = pkgs.fetchFromGitHub {
          owner = "zsh-users";
          repo = "zsh-autosuggestions";
          rev = "v0.7.1";
          sha256 = "sha256-vpTyYq9ZgfgdDsWzjxVAE7FZH4MALMNZIFyEOBLm5Qo=";
        };
      }
      {
        name = "zsh-syntax-highlighting";
        src = pkgs.fetchFromGitHub {
          owner = "zsh-users";
          repo = "zsh-syntax-highlighting";
          rev = "0.7.1";
          sha256 = "sha256-gOG0NLlaJfotJfs+SUhGgLTNOnGLjoqnUp54V9aFJg8=";
        };
      }
    ];
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
      ];
    };
  };
}
