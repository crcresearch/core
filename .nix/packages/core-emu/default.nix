{inputs, ...}: {
  imports = [
    inputs.flake-parts.flakeModules.easyOverlay
  ];
  perSystem = {
    config,
    pkgs,
    final,
    ...
  }: {
    overlayAttrs = {
      inherit (config.packages) core-emu-daemon;
    };
    packages.core-emu-daemon = let
      inherit
        (pkgs.python3.pkgs)
        toPythonApplication
        callPackage
        ;
    in
      toPythonApplication (callPackage ./package.nix {
        nix-filter = inputs.nix-filter.lib;
      });
  };
}
