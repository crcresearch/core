{
  inputs,
  lib,
  self,
  ...
}: {
  flake = {
    overlays.core = final: prev: {
      core-emu = with prev.python3Packages; toPythonApplication core-emu;

      pythonPackagesExtensions =
        prev.pythonPackagesExtensions
        ++ [
          (pself: pprev: {core-emu = pself.callPackage ./core.nix {inherit (inputs) gitignore;};})
        ];
    };
  };
  perSystem = {
    config,
    self',
    inputs',
    pkgs,
    system,
    ...
  }: let
    pkgs = import inputs.nixpkgs {
      inherit system;

      overlays = [
        self.overlays.core
      ];
    };
  in {config = {_module.args.pkgs = pkgs;};};
}
