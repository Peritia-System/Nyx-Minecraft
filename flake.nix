{
  description = "Nyx-Modules";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
  };

  outputs = { self, nixpkgs, nix-minecraft, ... }: {
    nixosModules.minecraft-servers = {
      config,
      lib,
      pkgs,
      ...
    }: {
      imports = [
        ./minecraft
        nix-minecraft.nixosModules.minecraft-servers
      ];
      nixpkgs.overlays = [nix-minecraft.overlay];
    };
  };
}
