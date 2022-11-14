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
      in {
        options.services.core-emu = {
          enable = mkEnableOption (mdDoc "Common Open Research Emulator");

          package = mkOption {
            type = types.path;
            description = mdDoc "The CORE package to use";
            default = self.packages.${pkgs.hostPlatform.system}.core-emu;
            defaultText = literalExpression "self.packages.core-emu";
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

          environment.systemPackages = [cfg.package];

          environment.etc."core/core.conf".source = "${cfg.package}/etc/core/core.conf";
          environment.etc."core/logging.conf".source = "${cfg.package}/etc/core/logging.conf";

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
                  exec ${cfg.package}/bin/core-daemon
                '';
              in "${watchdog}/bin/core-daemon-watchdog";
            };
          };
        };
      };
  };
}
