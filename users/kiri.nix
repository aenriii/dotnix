{ pkgs, inputs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;

  # Also the interpreter wake_kiri.sh/memory_store.py need on PATH (see the
  # `Environment = "PATH=..."` lines in hosts/deaddove/services/kiri.nix) --
  # memory_store.py's semantic memory system needs faiss + sentence-transformers
  # on top of the plain CLI-tool deps.
  pythonEnv = pkgs.python3.withPackages (
    ps: with ps; [
      numpy # f2py, numpy-config
      sympy # isympy
      torch # torchrun, torchfrtrace
      transformers
      huggingface-hub # hf, huggingface-cli, tiny-agents
      tqdm
      typer
      markdown-it-py # markdown-it
      httpx
      faiss
      sentence-transformers
    ]
  );
in
{
  home = {
    username = "kiri";
    homeDirectory = "/home/kiri";
    stateVersion = "25.11";
  };

  # Declarative replacements for what was hand-installed under ~/.local/bin
  # on her old box. Not covered here: `proton`/`proton-viewer` -- nixpkgs'
  # triton build doesn't expose those two console scripts, so her existing
  # copies are what's there for now.
  home.packages = with pkgs; [
    bun # bunx
    inputs.claude-code.packages.${system}.claude-code
    pythonEnv
  ];

  # Her always-on Telegram gateway/heartbeat glue, moved into the repo so it
  # can be edited and reviewed here instead of hand-edited live. Per her own
  # AGENTS.md ("Aenri controls this file") this operational layer is Aenri's
  # to manage -- unlike IDENTITY.md/SOUL.md/journal/, which are explicitly
  # hers to self-edit and are deliberately left untouched by this repo.
  home.file = {
    "glue/kiri-gateway.py".source = ./kiri/glue/kiri-gateway.py;
    "glue/wake_kiri.sh".source = ./kiri/glue/wake_kiri.sh;
    "glue/heartbeat.sh".source = ./kiri/glue/heartbeat.sh;
    "glue/newsession.sh".source = ./kiri/glue/newsession.sh;
    "glue/send_telegram.sh".source = ./kiri/glue/send_telegram.sh;
    "glue/memory_store.py".source = ./kiri/glue/memory_store.py;
    "glue/config.json".source = ./kiri/glue/config.json;
  };
}
