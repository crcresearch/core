{
  description = "CORE (Common Open Research Emulator) is a tool for building virtual networks.";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    {
      overlays.default = final: prev: {
        core-emu = with prev.python3Packages; toPythonApplication core-emu;

        pythonPackagesExtensions =
          prev.pythonPackagesExtensions
          ++ [
            (pself: pprev: {
              core-emu = pself.callPackage ./package.nix {};
            })
          ];
      };
    }
    // flake-utils.lib.eachSystem [flake-utils.lib.system.x86_64-linux] (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          self.overlays.default
        ];
      };
    in {
      devShells.default = self.packages.${system}.core-python.env;

      formatter = pkgs.alejandra;

      packages = flake-utils.lib.flattenTree {
        default = pkgs.core-emu;
        core-python = pkgs.python3.withPackages (p:
          with p; [
            core-emu
          ]);
        core-daemon = pkgs.buildFHSUserEnv {
          name = "core-daemon";
          targetPkgs = pkgs: (with pkgs; [
            util-linux
            coreutils
            mount
            umount
            sysctl
            nftables
            ethtool
            iproute2
            docker-client
            self.packages.${system}.core-python
          ]);
          runScript = "${self.packages.${system}.core-python}/bin/core-daemon";
        };
      };
    });
}
