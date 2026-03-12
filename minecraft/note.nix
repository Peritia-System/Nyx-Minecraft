{ config, lib, pkgs, ... }:

let
  cfg = config.nyx-minecraft;
in
{
  config = lib.mkIf (cfg.enable && !cfg.ignoreDeprecationNote) {
    warnings = [
      ''
      ###########################
      #   !!!   Warning   !!!   #
      ###########################
      
      Nyx-Minecraft has moved!

      This repository is no longer maintained.
      Please use the new repository:

      https://git.alovely.space/Nyx/Nyx-Minecraft

      If this note bothers you and you do not care about any changes to the repo:
      add this to your config:

        nyx-minecraft.ignoreDeprecationNote = true;

      or switch to the new repo:

      nyx-minecraft.url = "git+https://git.alovely.space/Nyx/Nyx-Minecraft";
      
      ''
    ];
  };
}