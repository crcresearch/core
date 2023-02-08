{
  lib,
  self,
  moduleWithSystem,
  ...
}: {
  perSystem = {pkgs, ...}: {
    packages.vm = let
      image = pkgs.nixos ({pkgs, ...}: {
        imports = [
          self.nixosModules.core
        ];

        config = {
          services.core-emu.enable = true;
          services.core-emu.logging.loggers."".level = "DEBUG";
          services.core-emu.logging.loggers."core".level = "DEBUG";
          services.core-emu.logging.loggers."__main__".level = "DEBUG";

          services.getty.autologinUser = lib.mkDefault "root";
          users = {
            mutableUsers = false;
            # P@ssw0rd
            users.root.initialHashedPassword = "$6$WckEbJSAyYlddJni$l.h.AyA.yVc/yOFC8R5tRQaJoENk9Ec2iu6w9HyfdcgTzK9iolNCq1gSt0FAN1Bj6ZSvDKH8FiOW2XyJyFgod1";
          };
        };
      });
    in
      image.config.system.build.vm;
  };

  flake = {
    nixosModules.core = moduleWithSystem (
      perSystem @ {config}: nixos @ {
        pkgs,
        lib,
        config,
        ...
      }:
        with lib; let
          cfg = config.services.core-emu;
          settingsFormat = pkgs.formats.ini {};
          logSettingsFormat = pkgs.formats.json {};
        in {
          options.services.core-emu = {
            enable = mkEnableOption (mdDoc "Common Open Research Emulator");

            package = mkOption {
              type = types.path;
              description = mdDoc "The CORE package to use";
              default = perSystem.config.packages.core-emu;
              defaultText = literalExpression "self.packages.core-emu";
            };

            settings = lib.mkOption {
              description =
                lib.mdDoc ''
                '';
              type = lib.types.submodule {
                freeformType = settingsFormat.type;

                options = {
                  core-daemon = {
                    listenaddr = lib.mkOption {
                      type = lib.types.str;
                      default = "localhost";
                      description = ''
                        Which address the daemon service should listen on.
                      '';
                    };

                    port = lib.mkOption {
                      type = lib.types.port;
                      default = 4038;
                      description = ''
                        Which port the daemon service should listen on.
                      '';
                    };

                    grpcaddress = lib.mkOption {
                      type = lib.types.str;
                      default = "localhost";
                      description = ''
                        Which address the GRPC service should listen on.
                      '';
                    };

                    grpcport = lib.mkOption {
                      type = lib.types.port;
                      default = 50051;
                      description = ''
                        Which port the GRPC service should listen on.
                      '';
                    };
                  };
                };
              };
            };

            logging = lib.mkOption {
              description =
                lib.mdDoc ''
                '';
              type = lib.types.submodule {
                freeformType = logSettingsFormat.type;
              };
            };
          };

          config = mkIf cfg.enable {
            # Enable docker as a requirement
            virtualisation.docker = {
              enable = true;
              daemon.settings = {
                bridge = "none";
                iptables = false;
              };
            };

            # Add the package to the system to make it easier for users to run
            environment.systemPackages = [
              cfg.package
              perSystem.config.packages.emane.out
            ];

            # Set some default settings
            services.core-emu.settings = {
              core-daemon = {
                quagga_bin_search = "${perSystem.config.packages.ospf-mdr}/bin/";
                quagga_sbin_search = "${perSystem.config.packages.ospf-mdr}/libexec/quagga/";
                frr_bin_search = "${pkgs.frr}/bin";
                frr_sbin_search = "${pkgs.frr}/libexec/frr";
                emane_prefix = "${perSystem.config.packages.emane}";
              };
            };

            services.core-emu.logging = {
              version = 1;
              handlers = {
                console = {
                  class = "logging.StreamHandler";
                  formatter = "default";
                  level = lib.mkDefault "DEBUG";
                  stream = "ext://sys.stdout";
                };
              };
              formatters = {
                default = {
                  format = "%(asctime)s - %(levelname)s - %(module)s:%(funcName)s - %(message)s";
                };
              };
              loggers = {
                "" = {
                  level = lib.mkDefault "WARNING";
                  handlers = ["console"];
                  propagate = false;
                };

                core = {
                  level = lib.mkDefault "INFO";
                  handlers = ["console"];
                  propagate = false;
                };

                "__main__" = {
                  level = lib.mkDefault "INFO";
                  handlers = ["console"];
                  propagate = false;
                };
              };
            };

            # Generate etc configs
            environment.etc."core/core.conf".source = settingsFormat.generate "core-config.conf" cfg.settings;
            environment.etc."core/logging.conf".source = logSettingsFormat.generate "core-logging.conf" cfg.logging;

            # Create daemon service
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
                          $(${pkgs.netcat}/bin/nc -z -w 1 ${cfg.settings.core-daemon.grpcaddress} ${builtins.toString cfg.settings.core-daemon.grpcport} &> /dev/null) || FAIL=1
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
                    exec ${cfg.package}/bin/core-daemon
                  '';
                in "${watchdog}/bin/core-daemon-watchdog";
              };
            };
          };
        }
    );
  };
}
