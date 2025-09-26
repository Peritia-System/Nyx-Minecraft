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
      
      # leaving whitelis out just deactivates whitelist
      # leaving Operators out will just not set any operator
      
      # Leaving out a property will just set the default 
      properties = {
        serverPort   = 25565;
        # note you don't need to set query or rcon port 
        # since they will be set 200 and 100 above the Serverport
      };
      # you can leave them out than but here a simple example
      schedules = {
        # Hourly world-only, pure rsync, no restart
        greeting-hourly = {
          enable = true;
          # note schedule can be enabled without the server being enabled 
          timer  = "hourly"; 
          code   = ''
            minecraft-testingServer-say "yellow" "hello"
            # now once an hour it will greet everyone in the server
          '';
          };

        };
      };
    };
  };
};