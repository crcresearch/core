{
  description = "CORE (Common Open Research Emulator) is a tool for building virtual networks.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    gitignore,
  }:
    {
      overlays.default = final: prev: {
        core-emu = with prev.python3Packages; toPythonApplication core-emu;

        pythonPackagesExtensions =
          prev.pythonPackagesExtensions
          ++ [
            (pself: pprev: {
              core-emu = pself.callPackage ./package.nix {inherit gitignore;};
            })
          ];
      };

      nixosModules.default = {
        pkgs,
        lib,
        config,
        core-emu,
        ...
      }:
        with lib; let
          cfg = config.services.core-emu;
        in {
          options.services.core-emu = {
            enable = mkEnableOption (mdDoc "Common Open Research Emulator");

            package = mkOption {
              type = types.path;
              description = mdDoc "The CORE package to use";
              default = pkgs.core-emu;
              defaultText = literalExpression "pkgs.core-emu";
            };
          };

          config = mkIf cfg.enable {
            virtualisation.docker = {
              enable = true;
              daemon.settings = {
                bridge = "none";
                iptables = false;
              };
            };

            environment.systemPackages = [pkgs.core-emu];

            environment.etc."core/core.conf".source = "${pkgs.core-emu}/etc/core/core.conf";
            environment.etc."core/logging.conf".source = "${pkgs.core-emu}/etc/core/logging.conf";

            systemd.services.core-daemon = {
              description = "Common Open Research Emulator Service";
              wantedBy = ["multi-user.target"];
              after = ["docker.service"];
              serviceConfig = {
                Type = "notify";
                WatchdogSec = "10";
                NotifyAccess = "all";
                ExecStart = let
                  watchdog = pkgs.writeShellScriptBin "core-daemon-watchdog" ''
                    watchdog() {
                      READY=0;

                      PID=$1
                      while(true); do
                          FAIL=0
                          $(${pkgs.netcat}/bin/nc -z -w 1 localhost 50051 &> /dev/null) || FAIL=1
                          if [[ $FAIL -eq 0 ]]; then
                              if [[ $READY -eq 0 ]]; then
                                ${pkgs.systemdMinimal}/bin/systemd-notify --ready
                              fi
                              ${pkgs.systemdMinimal}/bin/systemd-notify WATCHDOG=1;
                              sleep $(($WATCHDOG_USEC / 1000000 / 2))
                          else
                              sleep 1
                          fi
                      done
                    }
                    watchdog $$ &
                    exec ${pkgs.core-emu}/bin/core-daemon
                  '';
                in "${watchdog}/bin/core-daemon-watchdog";
              };
            };
          };
        };
    }
    // flake-utils.lib.eachSystem [flake-utils.lib.system.x86_64-linux] (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [self.overlays.default];
      };
    in rec {
      devShells.default = packages.core-python;

      formatter = pkgs.alejandra;

      packages = flake-utils.lib.flattenTree {
        default = pkgs.core-emu;
        core-python = pkgs.python3.withPackages (p: [p.core-emu]);
      };
    });
}
