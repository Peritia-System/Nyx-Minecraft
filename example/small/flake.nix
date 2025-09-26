{
  description = "EXAMPLE - Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    # your own imports
    nyx-minecraft.url = "github:Peritia-System/Nyx-Minecraft";
    nyx-minecraft.inputs.nixpkgs.follows = "nixpkgs";

  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nix-minecraft,
    ...
  }: {
    nixosConfigurations = {
      yourSystem = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        specialArgs = {
          inherit inputs self;
          host = "yourSystem";
        };

        modules = [
          nixos95.nixosModules.default
         
          ./configuration.nix
        ];
      };
  };
}
