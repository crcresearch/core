{
  flake = {
    nixosModules.core = {
      pkgs,
      lib,
      config,
      ...
    }:
      with lib; let
        cfg = config.services.core-emu;
        settingsFormat = pkgs.formats.ini {};
      in {
        options.services.core-emu = {
          enable = mkEnableOption (mdDoc "Common Open Research Emulator");

          package = mkOption {
            type = types.path;
            description = mdDoc "The CORE package to use";
            default = self.packages.${pkgs.hostPlatform.system}.core-emu;
            defaultText = literalExpression "self.packages.core-emu";
          };

          settings = lib.mkOption {
            type = lib.types.submodule {
              freeformType = with lib.types; attrsOf (oneOf [bool int float str]);

              options.port = lib.mkOption {
                type = lib.types.port;
                default = 4038;
                description = ''
                  Which port thi service should listen on.
                '';
              };

              options.grpcport = lib.mkOption {
                type = lib.types.port;
                default = 50051;
                description = ''
                  Which port the GRPC service should listen on.
                '';
              };
            };
            default = {};
            description = ''
            '';
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
          environment.systemPackages = [cfg.package];

          # Set some default settings
          services.core-emu.settings = {
            listenaddr = lib.mkDefault "localhost";
            grpcaddress = lib.mkDefault "localhost";
          };

          # Generate etc configs
          environment.etc."core/core.conf".source = settingsFormat.generate "core-config.conf" {
            core-daemon = cfg.settings;
          };
          environment.etc."core/logging.conf".source = "${cfg.package}/etc/core/logging.conf";

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
                        $(${pkgs.netcat}/bin/nc -z -w 1 ${cfg.settings.grpcaddress} ${builtins.toString cfg.settings.grpcport} &> /dev/null) || FAIL=1
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
      };
  };
}
