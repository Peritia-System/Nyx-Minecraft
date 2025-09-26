{
  config,
  lib,
  pkgs,
  ...
}:

imports = [
  
  # ... your imports
     inputs.nyx-minecraft.nixosModules.minecraft-servers
   ];
 
  nyx-minecraft.service = {
    enable = true;
    eula = true; 
    # user   # don't change this
    # group  # don't change this
    dataDir = "srv/minecraft";

    servers = {
      testingServer = {
        enable = true;

        memory = {
          min = "2G";
          max = "4G";
        };

        package = pkgs.minecraftServers.vanilla-1_20_4;
        autoStart = true;

        whitelist = {
          player1 = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
          player2 = "ffffffff-1111-2222-3333-444444444444";
        };

        operators = {
          admin = {
            uuid = "99999999-aaaa-bbbb-cccc-dddddddddddd";
            level = 4;
            bypassesPlayerLimit = true;
          };
          mod = {
            uuid = "88888888-aaaa-bbbb-cccc-eeeeeeeeeeee";
            level = 2;
            bypassesPlayerLimit = false;
          };
        };

        properties = {
          serverPort   = 25565;
          difficulty   = 2;
          gamemode     = 0;
          maxPlayers   = 20;
          motd         = "Welcome to the testingServer!";
          rconPassword = "superSecret123";
          hardcore     = false;
          levelSeed    = "8675309";
        };

        schedules = {
          # note schedule can be enabled without the server being enabled 
          backup-hourly = {
            enable = true;
            # this is using systemD timers check the official Documentation
            timer  = "hourly"; 
            code   = ''
              minecraft-testingServer-backup-routine \
                --sleep 16 \
                --destination /srv/minecraft/backups/testingServer/hourly \
                --pure
            '';
          };
          backup-daily = {
            enable = true;
            timer  = "daily";
            code   = ''
              minecraft-testingServer-backup-routine \
                --sleep 60 \
                --destination /srv/minecraft/backups/testingServer/daily \
                --format zip
            '';
          };
          backup-weekly = {
            enable = true;
            timer  = "weekly";
            code   = ''
              minecraft-testingServer-backup-routine \
                --sleep 600 \
                --full \
                --destination /srv/minecraft/backups/testingServer/weekly \
                --format zip 
            '';
          };
          backup-monthly = {
            enable = true;
            timer  = "monthly";
            code   = ''
              minecraft-testingServer-backup-routine \
                --sleep 960 \
                --full \
                --destination /srv/minecraft/backups/testingServer/monthly \
                --format zip 
            '';
          };

        };
      };
    };
  };
};