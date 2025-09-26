# Yet another Nix Minecraft module

This NixOS module extends [Infinidoge/nix-minecraft](https://github.com/Infinidoge/nix-minecraft) with additional features for managing multiple Minecraft servers declaratively.

## Features

- Declarative configuration of multiple Minecraft servers

- Control over memory, operators, whitelist, symlinks, and server properties

- Automatic **systemd services** and **timers** for scheduled jobs

- Prebuilt helper scripts for administration:

  - `rcon`
  - `query`
  - `backup`
  - `say`
  - `backup-routine`

- Support for:

  - Backups
  - Logging
  - Scheduled maintenance tasks

## Helper Scripts

For each server defined, helper scripts are generated into your system `$PATH`.
They follow the naming convention:

```bash
minecraft-<SERVERNAME>-<TASK>
# Example:
minecraft-myserver-say "yellow" "hello"
```

You can inspect the generated scripts under: `minecraft/Scripts`

## Configuration Options

```nix
nyx-minecraft.service = {
  enable  = true;              # Enable the enhanced servers (boolean)
  eula    = true;              # I can't accept this for you  
  user    = "minecraft";       # System user that owns/runs servers     - DON'T CHANGE THIS 
  group   = "minecraft";       # System group that owns/runs servers    - DON'T CHANGE THIS
  dataDir = "/srv/minecraft";  # Directory for Minecraft server data

  servers = {
    myserver = {
      enable = true;
      memory.min = "2G";       # JVM minimum memory
      memory.max = "4G";       # JVM maximum memory

      # This will be directly exposed to [Nix-Minecraft](https://github.com/Infinidoge/nix-minecraft/tree/master?tab=readme-ov-file#packages)
      # Check their documentation for available options.
      package   = pkgs.minecraftServers.vanilla-1_20_4;

      autoStart = true;        # Start server on boot

      whitelist = {            # Declarative whitelist (UUIDs per user)
        alice = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
        bob   = "ffffffff-1111-2222-3333-444444444444";
      };

      operators = {            # Declarative operator list
        alice = {
          uuid  = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
          level = 4;
        };
      };

      properties = {           # Declarative `server.properties`
        serverPort = 25565;
        motd       = "Welcome to my NixOS server!";
        maxPlayers = 10;
      };

      schedules.backup = {     # Systemd timer + service job
        timer = "daily";
        code  = "minecraft-myserver-backup";
      };
    };
  };
};
```

For more details, refer to the [official nix-minecraft documentation](https://github.com/Infinidoge/nix-minecraft), since most arguments are passed through.

### Server Options

- **memory.min / memory.max** — JVM memory allocation (e.g. `"2G"`)
- **package** — Minecraft server package (default: `pkgs.minecraft-server`)
- **autoStart** — Start on boot (`true` / `false`)
- **whitelist** — Declarative whitelist keyed by username with UUID
- **operators** — Operator list with permission levels (`0–4`)
- **symlinks** — Files/packages symlinked into server data directory
- **properties** — Declarative `server.properties` values (ports, motd, difficulty, etc.)
- **schedules** — Declarative scheduled jobs (with systemd timers and services)

## Examples

See the examples in:

- `./example/full`
- `./example/small`

## Warnings

- **Use at your own risk** — verify backups and test schedules before relying on them
- Pin a known working version for stable usage
- Perform **manual backups before updates**

## Contributing

I am happy to help with issues and welcome pull requests for improvements.
Since I use this module personally, you can expect frequent updates.
