# Enhanced Minecraft Server Module
#
# This module provides:
#   - A wrapper around the Infinidoge/nix-minecraft module
#   - Declarative configuration for multiple servers, including memory, operators, whitelist, and symlinks
#   - Automatic systemd service and timer generation for scheduled jobs
#   - Prebuilt helper scripts (rcon, query, backup, say, backup-routine) for server administration
#   - Support for backups, logging, and scheduled maintenance tasks
#
# Configuration Options:
#   enable        – Enable the enhanced Minecraft servers (boolean)
#   user          – System user that owns and runs the servers (string)  - DON'T CHANGE THIS
#   group         – System group that owns and runs the servers (string) - DON'T CHANGE THIS
#   dataDir       – Directory to store Minecraft server data (path)
#   servers       – Attribute set of servers, keyed by name. Each server can define:
#       memory.min / memory.max   – JVM memory allocation (strings, e.g. "2G")
#       package                   – Minecraft server package to use (package)
#       autoStart                 – Start server at boot (boolean)
#       whitelist                 – Declarative whitelist (UUIDs per user)
#       operators                 – Declarative operator list with permission levels
#       symlinks                  – Files or packages symlinked into the server data directory
#       properties                – Declarative `server.properties` values (ports, motd, difficulty, etc.)
#       schedules                 – Declarative scheduled jobs with systemd timers and services
#
#
# Info:
# I am happy to help if you have Issues and am happy to see a PR for any change
# I ll use it personally too so you can expect frequent updates
#
#
# ToDo:
# Schedule to restart a server using systemD. I have not figured that out yet.
# what i do know is that `sudo` does not work neither does it work if you just tell the server to restart.
#
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nyx-minecraft.service;
  minecraftUUID = types.strMatching "[0-9a-fA-F-]{36}";

  # Setup the Scripts for the server
  scriptDir = ./Scripts;
  mkScript = serverName: serverCfg: scriptType: let
    templateFile = scriptDir + "/minecraft-template-${scriptType}.sh";
    rawText = builtins.readFile templateFile;
    scriptText =
      builtins.replaceStrings
      [
        "@DATA_DIR@"
        "@RSYNC_BIN@"
        "@MCSTATUS_BIN@"
        "@MCRCON_BIN@"
        "@AWK_BIN@"
        "@QUERY_PORT@"
        "@RCON_PORT@"
        "@RCON_PASSWORD@"
        "@SERVER_NAME@"
        "@TAR_BIN@"
        "@ZIP_BIN@"
        "@UNZIP_BIN@"
        "@GZIP_BIN@"
        "@ZSTD_BIN@"
        "@PV_BIN@"
        "@DU_BIN@"
        "@BZIP2_BIN@"
        "@XZ_BIN@"
      ]
      # If you add anything here make sure to add it at the systemd service too
      [
        cfg.dataDir
        "${pkgs.rsync}/bin/rsync"
        "${pkgs.mcstatus}/bin/mcstatus"
        "${pkgs.mcrcon}/bin/mcrcon"
        "${pkgs.gawk}/bin/awk"
        (toString (serverCfg.properties.serverPort + 200))
        (toString (serverCfg.properties.serverPort + 100))
        serverCfg.properties.rconPassword
        serverName
        "${pkgs.gnutar}/bin/tar"
        "${pkgs.zip}/bin/zip"
        "${pkgs.unzip}/bin/unzip"
        "${pkgs.gzip}/bin/gzip"
        "${pkgs.zstd}/bin/zstd"
        "${pkgs.pv}/bin/pv"
        "${pkgs.coreutils}/bin/du"
        "${pkgs.bzip2}/bin/bzip2"
        "${pkgs.xz}/bin/xz"
      ]
      rawText;
  in
    pkgs.writeShellScriptBin "minecraft-${serverName}-${scriptType}" scriptText;
in {
  # Note most of the options get directly exposed
  # to nix-minecraft which makes it almost an
  # Drop in replacement
  options.nyx-minecraft.service = {
    enable = mkEnableOption "Enable enhanced Minecraft servers with backup, logging, and admin helpers.";

    eula = mkEnableOption ''
      Whether you agree to
      <link xlink:href="https://account.mojang.com/documents/minecraft_eula">
      Mojang's EULA</link>. This option must be set to
      <literal>true</literal> to run Minecraft server.
    '';

    user = mkOption {
      type = types.str;
      default = "minecraft";
      description = ''
        Name of the user to create and run servers under.
        It is recommended to leave this as the default, as it is
        the same user as <option>services.minecraft-server</option>.
      '';
      internal = true;
      visible = false;
    };

    group = mkOption {
      type = types.str;
      default = "minecraft";
      description = ''
        Name of the group to create and run servers under.
        In order to modify the server files your user must be a part of this
        group. If you are using the tmux management system (the default), you also need to be a part of this group to attach to the tmux socket.
        It is recommended to leave this as the default, as it is
        the same group as <option>services.minecraft-server</option>.
      '';
    };

    dataDir = mkOption {
      type = types.path;
      default = "/srv/minecraft";
      description = ''
        Directory to store the Minecraft servers.
        Each server will be under a subdirectory named after
        the server name in this directory, such as <literal>/srv/minecraft/servername</literal>. '';
    };

    servers = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          enable = mkEnableOption "Enable this Server";

          memory = mkOption {
            type = types.submodule {
              options = {
                min = mkOption {
                  type = types.str;
                  default = "2G";
                  description = "Min JVM memory.";
                };
                max = mkOption {
                  type = types.str;
                  default = "2G";
                  description = "Max JVM memory.";
                };
              };
            };
            default = {
              min = "2G";
              max = "2G";
            };
            description = "JVM memory settings for this server.";
          };

          package = mkOption {
            description = "The Minecraft server package to use.";
            type = types.package;
            default = pkgs.minecraft-server;
            defaultText = literalExpression "pkgs.minecraft-server";
            example = "pkgs.minecraftServers.vanilla-1_18_2";
          };

          autoStart = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Whether to start this server on boot.
              If set to <literal>false</literal>, it can still be started with
              <literal>systemctl start minecraft-server-servername</literal>.
              Requires the server to be enabled.
            '';
          };

          whitelist = mkOption {
            type = types.attrsOf minecraftUUID;
            default = {};
            description = ''
              Whitelisted players, only has an effect when
              enabled via <option>services.minecraft-servers.<name>.serverProperties</option>
              by setting <literal>white-list</literal> to <literal>true</literal>.

              To use a non-declarative whitelist, enable the whitelist and don't fill in this value.
              As long as it is empty, no whitelist file is generated.
            '';
            example = literalExpression ''
              {
                username1 = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
                username2 = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy";
              }
            '';
          };

          symlinks = mkOption {
            type = types.attrsOf (types.either types.path types.package);
            default = {};
            description = ''
              Things to symlink into this server's data directory.
              Can be used to declaratively manage arbitrary files (e.g., mods, configs).
            '';
          };

          customJVMOpts = mkOption {
            description = "Additional JVM options";
            type =
              types.coercedTo
              types.str
              (lib.splitString " ")
              (types.listOf types.str);
            default = [];
            example = [
              "-Dminecraft.api.env=custom"
              "-Dminecraft.api.auth.host=https://mcauth.example.space/auth"
            ];
          };

          operators = mkOption {
            type = types.attrsOf (
              types.coercedTo minecraftUUID (v: {uuid = v;}) (
                types.submodule {
                  options = {
                    uuid = mkOption {
                      type = minecraftUUID;
                      description = "The operator's UUID";
                      example = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
                    };
                    level = mkOption {
                      type = types.ints.between 0 4;
                      description = "The operator's permission level";
                      default = 4;
                    };
                    bypassesPlayerLimit = mkOption {
                      type = types.bool;
                      description = "If true, the operator can join the server even if the player limit has been reached";
                      default = false;
                    };
                  };
                }
              )
            );
            default = {};
            description = "Operators with permission levels.";
          };

          properties = mkOption {
            type = types.submodule {
              options = {
                serverPort = mkOption {
                  type = types.int;
                  default = 25565;
                  description = "Server Port";
                };
                difficulty = mkOption {
                  type = types.int;
                  default = 2;
                  description = "Difficulty in numbers: 0=Peaceful, 1=Easy, 2=Normal, 3=Hard";
                };
                gamemode = mkOption {
                  type = types.int;
                  default = 0;
                  description = "Gamemode: 0=Survival, 1=Creative";
                };
                maxPlayers = mkOption {
                  type = types.int;
                  default = 5;
                  description = "How many players can join the server";
                };
                motd = mkOption {
                  type = types.str;
                  default = "NixOS Minecraft server!";
                  description = "Message displayed when selecting the server";
                };
                rconPassword = mkOption {
                  type = types.str;
                  default = "superSecret";
                  description = "Password for Rcon";
                };
                hardcore = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Enable Hardcore mode";
                };
                levelSeed = mkOption {
                  type = types.str;
                  default = "42";
                  description = "World seed (default is the answer to the universe)";
                };
              };
            };
            default = {};
            description = "Declarative Minecraft server.properties values.";
          };

          # userActivity = {
          #   enable = mkOption {
          #     type = types.bool;
          #     default = false;
          #     description = ''
          #       Enable periodic user activity logging for this server.
          #       Writes to <dataDir>/<server>/UserActivity and is used by
          #       backup --check-user.
          #     '';
          #   };

          #   interval = mkOption {
          #     type = types.str;
          #     default = "5min";
          #     example = "1min";
          #     description = ''
          #       How often user activity should be logged.
          #       Uses systemd.time format (e.g. 30s, 1min, 5min).
          #     '';
          #   };
          # };

          schedules = mkOption {
            type = types.attrsOf (types.submodule ({name, ...}: {
              options = {
                enable = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Whether this schedule is active.";
                };

                timer = mkOption {
                  type = types.str;
                  example = "hourly";
                  description = "Systemd timer unit specifier (e.g., hourly, daily, weekly).";
                };

                code = mkOption {
                  type = types.lines;
                  description = "Shell code to execute when the schedule fires.";
                };

                # Not properly enough tested
                #customEnviorment = mkOption {
                #  type = types.lines;
                #  description = "to expose binaries or other things to the SystemD service";
                #  example = "ZSTD_BIN=${pkgs.zstd}/bin/zstd";
                #};
              };
            }));
            default = {};
            description = "Scheduled jobs for this Minecraft server.";
          };
        };
      }));
      default = {};
      description = "Servers to run under the enhanced Minecraft service.";
    };
  };

  # Wrapper for nix-minecraft
  config = mkIf cfg.enable {
    services.minecraft-servers = {
      enable = true;
      eula = cfg.eula;
      openFirewall = true;
      user = cfg.user;
      group = cfg.group;
      dataDir = cfg.dataDir;

      servers =
        lib.mapAttrs (serverName: serverCfg: {
          enable = serverCfg.enable;
          package = serverCfg.package;

          jvmOpts = lib.concatStringsSep " " (
            [
              "-Xmx${serverCfg.memory.max}"
              "-Xms${serverCfg.memory.min}"
            ]
            ++ serverCfg.customJVMOpts
          );

          autoStart = serverCfg.autoStart;

          symlinks = serverCfg.symlinks;
          whitelist = serverCfg.whitelist;
          operators = serverCfg.operators;

          serverProperties = {
            enable-rcon = true;
            enable-command-block = true;
            allow-flight = true;
            enable-query = true;
            server-port = serverCfg.properties.serverPort;
            difficulty = serverCfg.properties.difficulty;
            gamemode = serverCfg.properties.gamemode;
            max-players = serverCfg.properties.maxPlayers;
            motd = serverCfg.properties.motd;
            "rcon.password" = serverCfg.properties.rconPassword;
            "rcon.port" = serverCfg.properties.serverPort + 100;
            "query.port" = serverCfg.properties.serverPort + 200;

            hardcore = serverCfg.properties.hardcore;
            level-seed = serverCfg.properties.levelSeed;
          };
        })
        cfg.servers;
    };

    # Schedule logic
    systemd.services = lib.mkMerge (
      lib.mapAttrsToList (
        serverName: serverCfg:
          lib.mapAttrs' (scheduleName: scheduleCfg: let
            # yes this will be building the scripts twice but thsi
            # way the path is accessible by the SystemD service
            rconBin = mkScript serverName serverCfg "rcon";
            queryBin = mkScript serverName serverCfg "query";
            backupBin = mkScript serverName serverCfg "backup";
            sayBin = mkScript serverName serverCfg "say";
            routineBin = mkScript serverName serverCfg "backup-routine";
            userActivityBin = mkScript serverName serverCfg "user-activity";
          in {
            name = "minecraft-${serverName}-${scheduleName}";
            value = {
              description = "Minecraft ${serverName} scheduled job: ${scheduleName}";
              serviceConfig = {
                Type = "oneshot";
                User = cfg.user;
                Group = cfg.group;
                Environment = [
                  "RCON_BIN=${rconBin}/bin/minecraft-${serverName}-rcon"
                  "QUERY_BIN=${queryBin}/bin/minecraft-${serverName}-query"
                  "USERACTIVITY_BIN=${userActivityBin}/bin/minecraft-${serverName}-user-activity"
                  "BACKUP_BIN=${backupBin}/bin/minecraft-${serverName}-backup"
                  "SAY_BIN=${sayBin}/bin/minecraft-${serverName}-say"
                  "ROUTINE_BIN=${routineBin}/bin/minecraft-${serverName}-backup-routine"
                  "ZSTD_BIN=${pkgs.zstd}/bin/zstd"
                  # add more bin here

                  # Not properly enough tested
                  #
                  #scheduleCfg.customEnviorment
                ];
                ExecStart = pkgs.writeShellScript "minecraft-${serverName}-${scheduleName}.sh" ''
                  #!/usr/bin/env bash
                  echo "hi — available helpers:"
                  echo "if you want any custom scripts or"
                  echo "packages for your script you need to ExecStart"
                  echo "  $RCON_BIN"
                  echo "  $QUERY_BIN"
                  echo "  $BACKUP_BIN"
                  echo "  $SAY_BIN"
                  echo "  $ROUTINE_BIN"
                  echo "  $USERACTIVITY_BIN"


                  # this is so it can use the scripts the same way you would run them:
                  minecraft-${serverName}-query() { $QUERY_BIN "$@"; }
                  minecraft-${serverName}-rcon() { $RCON_BIN "$@"; }
                  minecraft-${serverName}-backup() { $BACKUP_BIN "$@"; }
                  minecraft-${serverName}-say() { $SAY_BIN "$@"; }
                  minecraft-${serverName}-backup-routine() { $ROUTINE_BIN "$@"; }
                  minecraft-${serverName}-user-activity() { $USERACTIVITY_BIN "$@"; }

                  # her your code will go:
                  ${scheduleCfg.code}

                '';
              };

              # If you have this on:
              # wantedBy = [ "multi-user.target" ];
              # it will run the service on each rebuild.
              # i dont want that you can enable it if you like
            };
          })
          serverCfg.schedules
      )
      cfg.servers
    );

    # the timers to actually run the SystemD service
    systemd.timers = lib.mkMerge (
      lib.mapAttrsToList (
        serverName: serverCfg:
          lib.mapAttrs' (scheduleName: scheduleCfg: {
            name = "minecraft-${serverName}-${scheduleName}";
            value = {
              description = "Timer for Minecraft ${serverName} schedule ${scheduleName}";
              wantedBy = ["timers.target"];
              timerConfig.OnCalendar = scheduleCfg.timer;
            };
          })
          serverCfg.schedules
      )
      cfg.servers
    );

    #     systemd.services = lib.mkMerge (
    #       lib.mapAttrsToList (serverName: serverCfg:
    #         lib.mkIf serverCfg.userActivity.enable {
    #           "minecraft-${serverName}-user-activity" = {
    #             description = "Minecraft ${serverName} user activity logger";
    #             serviceConfig = {
    #               Type = "oneshot";
    #               User = cfg.user;
    #               Group = cfg.group;
    #               Environment = [
    #                 "QUERY_BIN=${mkScript serverName serverCfg "query"}/bin/minecraft-${serverName}-query"
    #               ];
    #               ExecStart =
    #                 "${mkScript serverName serverCfg "user-activity"}/bin/minecraft-${serverName}-user-activity";
    #             };
    #           };
    #         }
    #       ) cfg.servers
    #     );

    # systemd.timers = lib.mkMerge (
    #   lib.mapAttrsToList (serverName: serverCfg:
    #     lib.mkIf serverCfg.userActivity.enable {
    #       "minecraft-${serverName}-user-activity" = {
    #         description = "Timer for Minecraft ${serverName} user activity logging";
    #         wantedBy = [ "timers.target" ];
    #         timerConfig = {
    #           OnBootSec = "2min";
    #           OnUnitActiveSec = serverCfg.userActivity.interval;
    #           AccuracySec = "30s";
    #         };
    #       };
    #     }
    #   ) cfg.servers
    # );

    # this is building the scripts for the user
    # Those are the prewritten scripts from the ./Script dir
    environment.systemPackages = lib.flatten (
      lib.mapAttrsToList (serverName: serverCfg: [
        (mkScript serverName serverCfg "rcon")
        (mkScript serverName serverCfg "query")
        (mkScript serverName serverCfg "backup")
        (mkScript serverName serverCfg "say")
        (mkScript serverName serverCfg "backup-routine")
        (mkScript serverName serverCfg "user-activity")
      ])
      cfg.servers
    );
  };
}
