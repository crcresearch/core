{
  description = "CORE (Common Open Research Emulator) is a tool for building virtual networks.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit self;} {
      imports = [
        ./nix/overlays.nix
        ./nix/packages.nix
        ./nix/nixosModules.nix
      ];
      systems = ["x86_64-linux"];
      perSystem = {inputs', ...}: {
        formatter = inputs'.nixpkgs.legacyPackages.alejandra;
      };
    };
}
