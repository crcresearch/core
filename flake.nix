{
  description = "CORE (Common Open Research Emulator) is a tool for building virtual networks.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        ./nix/overlays.nix
        ./nix/packages.nix
        ./nix/nixosModules.nix
      ];
      systems = ["x86_64-linux" "aarch64-linux"];
      perSystem = {inputs', ...}: {
        formatter = inputs'.nixpkgs.legacyPackages.alejandra;
      };
    };
}
