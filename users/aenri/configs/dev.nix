{
  pkgs,
  inputs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  home.packages = with pkgs; [
    nixd
    nil
    rustup
    devenv
    inputs.claude-code.packages.${system}.claude-code
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
    ignores = [ "**/.claude/settings.local.json" ];
    settings = {
      user = {
        name = "Aenri Lovehart";
        email = "aenri@loveh.art";
      };
      init.defaultBranch = "main";
      advice.defaultBranchName = false;
    };
    signing = {
      key = "CC3624C1D78F4FEDD7522A22EC3014D92E7084DA";
      format = "openpgp";
      signByDefault = true;
      allowedSigners = ''
        aenri@lovehart.cc namespaces="git" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAvad2WciYhgG8UZyZAoVrbpFm/wnAnVpkoHTA2Drxht aenri@lovehart.cc signing
      '';
    };
  };

  programs.gpg.enable = true;
  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-gnome3;
    # Keygrip 68C393C9... (the "Aenri Rose Lovehart" identity) lives on a
    # hardware token, not in the software keyring -- scdaemon (on by
    # default) is what lets gpg-agent talk to it via pcscd.
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
