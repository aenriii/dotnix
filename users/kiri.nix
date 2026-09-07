{ pkgs, inputs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;


  pythonEnv = pkgs.python3.withPackages (
    ps: with ps; [
      numpy
      sympy
      torch
      transformers
      huggingface-hub
      tqdm
      typer
      markdown-it-py
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


  home.packages = with pkgs; [
    bun
    inputs.claude-code.packages.${system}.claude-code
    pythonEnv
  ];

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
