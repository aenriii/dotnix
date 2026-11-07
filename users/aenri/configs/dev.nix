{
  config,
  pkgs,
  ...
}:
let
  signing = config.dotnix.home.git.signing;
in
{
  home.packages = with pkgs; [
    nixd
    nil
    rustup
    devenv
    claude-code
  ];

  home.sessionPath = [ "$HOME/.cargo/bin" ];

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    withPython3 = true;
    withRuby = true;
  };

  programs.git = {
    enable = true;
    ignores = [ "**/.claude/" ];
    settings = {
      user = {
        name = "Aenri Lovehart";
        email = "aenri@loveh.art";
      };
      init.defaultBranch = "main";
      advice.defaultBranchName = false;
    };
    signing = {
      inherit (signing) key format;
      signByDefault = true;
      allowedSigners = ''
        aenri@lovehart.cc namespaces="git" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAvad2WciYhgG8UZyZAoVrbpFm/wnAnVpkoHTA2Drxht aenri@lovehart.cc signing
      '';
    };
  };

  programs.gpg.enable = true;
  services.gpg-agent = {
    enable = true;
    pinentry.package = 
      if pkgs.stdenv.hostPlatform.isDarwin 
      then pkgs.pinentry_mac 
      else pkgs.pinentry-gnome3;
  };

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
      prompt = "enabled";
      prefer_editor_prompt = "disabled";
      color_labels = "disabled";
      accessible_colors = "disabled";
      accessible_prompter = "disabled";
      spinner = "enabled";
      aliases.co = "pr checkout";
    };
  };
}
