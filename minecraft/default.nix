{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./minecraft.nix
  ];

    options.nyx-minecraft.ignoreDeprecationNote = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Disable the deprecation warning. And accept potential breakages. Aswell as no Updates.";
    };


}
