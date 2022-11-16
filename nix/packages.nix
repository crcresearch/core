{lib, ...}: {
  perSystem = {
    config,
    self',
    inputs',
    pkgs,
    system,
    ...
  }: let
    pythonPackages = lib.filterAttrs (n: v: builtins.match "python3[[:digit:]]+?" n != null) pkgs;
  in {
    packages =
      {
        default = pkgs.core-emu;
        core-emu = pkgs.core-emu;
        ospf-mdr = pkgs.ospf-mdr;
      }
      // (builtins.mapAttrs (name: value: value.withPackages (p: [p.core-emu])) pythonPackages);
  };
}
