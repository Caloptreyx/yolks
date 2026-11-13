# Yolks

Docker images for the [Caloptreyx game eggs](https://github.com/Caloptreyx/game-eggs), for Calagopus and Pterodactyl. They are rebuilt every Monday so Debian security updates get in, and on every change pushed to `main`.

| Image | Used for | Base |
|-------|----------|------|
| `ghcr.io/caloptreyx/installers:debian` | Egg install scripts | Debian 13 |
| `ghcr.io/caloptreyx/steamcmd:debian` | Linux game servers updated through SteamCMD (7 Days to Die, Palworld, ARK: Survival Evolved, American Truck Simulator, Euro Truck Simulator 2, Arma Reforger, Conan Exiles, Garry's Mod, Soulmask, Valheim, Unturned, Don't Starve Together, Project Zomboid, Satisfactory), plus Factorio and BeamMP | Debian 13 |
| `ghcr.io/caloptreyx/steamcmd:proton` | Windows game servers through GE-Proton (ARK: Survival Ascended, Windrose, Astroneer, Enshrouded, Icarus, SCUM) | Debian 13 |
| `ghcr.io/caloptreyx/games:rust` | Rust, with WebRCON console and Oxide/Carbon | Debian 13, Node.js 24 LTS |
| `ghcr.io/caloptreyx/games:dayz` | DayZ, with Workshop mod updates | Debian 13 |
| `ghcr.io/caloptreyx/games:arma3` | Arma 3, with Workshop mod updates and Headless Clients | Debian 13 |
| `ghcr.io/caloptreyx/games:bedrock` | Minecraft Bedrock Dedicated Server, updated on start | Debian 13 |
| `ghcr.io/caloptreyx/games:corekeeper` | Core Keeper, with the Xvfb display it needs | `steamcmd:debian` |
| `ghcr.io/caloptreyx/games:hytale` | Hytale, downloaded and updated on start | `java:25` |
| `ghcr.io/caloptreyx/games:horizon` | Horizon (Minecraft: Java Edition 26.3), installed and updated on start | `java:25` |
| `ghcr.io/caloptreyx/games:pathoftitans` | Path of Titans, updated on start, with an RCON console | `steamcmd:debian` |
| `ghcr.io/caloptreyx/java:8`, `:11`, `:17`, `:21`, `:25` | Minecraft: Java Edition, Mindustry and other Java servers | Debian 13, Eclipse Temurin JRE |
| `ghcr.io/caloptreyx/java:graalvm` | Java servers that want GraalVM | Debian 13, Oracle GraalVM JDK 25 |

## steamcmd

`/entrypoint.sh` updates the server through SteamCMD, then runs the panel's startup command through `eval`, with `{{VAR}}` replaced by `${VAR}`.

| Variable | Effect |
|----------|--------|
| `SRCDS_APPID` | Steam app to update; required for Proton |
| `AUTO_UPDATE` | `1` (default) updates on start, `0` skips it |
| `STEAM_USER`, `STEAM_PASS`, `STEAM_AUTH` | Steam login; anonymous when unset. Removed from the environment before the server starts |
| `WINDOWS_INSTALL` | `1` downloads the Windows depot |
| `SRCDS_BETAID`, `SRCDS_BETAPASS` | Beta branch and its password |
| `VALIDATE` | `1` validates all files during the update |
| `INSTALL_FLAGS`, `HLDS_GAME`, `UPDATE_STEAMWORKS` | Extra SteamCMD options |

Included tools: `rcon` ([gorcon/rcon-cli](https://github.com/gorcon/rcon-cli), RCON/telnet/WebRCON), `telnet`, `nc`, `perl`, `curl`. The Proton image also has `winetricks`.

The Proton version is pinned in `steamcmd/proton/Dockerfile` (`PROTON_VERSION`). Update it on purpose and retest the servers that use it; the build checks the release's sha512 checksum.

## games:rust

Updates the server and the selected framework (`FRAMEWORK`: `vanilla`, `oxide` or `carbon`) on start. Server output is shown until WebRCON is up; then the console is connected to WebRCON (`RCON_PORT`, `RCON_PASS`) so commands reach the server.

## games:dayz

Updates the server and `@workshopID` mods on start and runs DayZ with a user name for any container UID. See the entrypoint header for the variables.

## games:arma3

Updates the server (any branch, e.g. `creatordlc`) and `@workshopID` mods on start, installs mod keys, starts up to 5 Headless Clients and runs Arma 3 with a user name for any container UID. Mod update checks use the Steam Workshop API in one request; mods are hard-link copies of SteamCMD's downloads, renamed to lowercase, so updates only download what changed. See the entrypoint header for the variables.

## games:bedrock

Updates the Bedrock Dedicated Server on start (`AUTO_UPDATE`, default `1`) to `BEDROCK_VERSION`: `latest` (default), `preview` or a fixed version such as `1.21.50.10`. The installed version is kept in `.bedrock-version`, so nothing is downloaded when it is current. `server.properties`, `permissions.json`, `allowlist.json` and worlds are kept. The updater is also available as `bedrock-update`.

## games:corekeeper

`steamcmd:debian` plus Xvfb. The Core Keeper server needs a (virtual) display; keeping Xvfb in its own image avoids adding about 300 MB to `steamcmd:debian`. The egg starts Xvfb itself.

## games:hytale

Built on `java:25`. The Hytale game files need a Hytale account, so they are downloaded on start with the official downloader installed by the egg: on the first start the console shows a login URL and code. The downloader keeps its credentials in `.hytale-downloader-credentials.json`, so later updates need no login. `AUTO_UPDATE` (default `1`) and `HYTALE_PATCHLINE` (`release` or `pre-release`) control updates; the installed version is kept in `.hytale-version`.

## games:horizon

Built on `java:25`. Installs or updates Horizon's `horizon-server` on start (`horizon-update`: `HORIZON_VERSION`, `AUTO_UPDATE`) and prepares its game files from Mojang's Minecraft client and server with the image's Java (`PREPARE_GAME_FILES`), one exporter at a time so it fits in 1 GB. Then writes the panel's settings into `server.toml` with `horizon-server config set` and adds the listed players. See the entrypoint header for the variables. `java:25` must be built first: this image pulls it from GHCR.

## games:pathoftitans

Built on `steamcmd:debian`. Updates Path of Titans on start with Alderon's AlderonGamesCmd (`AG_AUTH_TOKEN`, `BETA_BRANCH`, `AUTO_UPDATE`), generates the server GUID once and a random RCON password per start when they are empty, and sends each console line to the server over Source RCON with `rcon`, since the server reads no console input. The server runs in the foreground, so the panel's SIGINT reaches it directly. AlderonGamesCmd has no versioned download: it is pinned by checksum in the Dockerfile (`ALDERON_CMD_SHA256`), and the build fails when Alderon replaces it. `steamcmd:debian` must be built first: this image pulls it from GHCR.

## java

Eclipse Temurin JRE on Debian 13, one tag per Java version, built from `java/Dockerfile`. `java:graalvm` is Oracle GraalVM JDK 25 (`java/graalvm/Dockerfile`, version pinned in `GRAAL_VERSION`). Both use `/entrypoint.sh`, which prints the Java version and runs the panel's startup command through `eval`, with `{{VAR}}` replaced by `${VAR}`.

## Publishing

The GitHub Actions workflows push to `ghcr.io/caloptreyx`. New packages on GHCR are private: after the first build, set each package (`installers`, `steamcmd`, `games`, `java`) to **Public** in its package settings so Wings can pull it without credentials.

`games:corekeeper` is built `FROM steamcmd:debian` and `games:hytale` `FROM java:25`, pulled from GHCR during the build. After changing `steamcmd/debian` or `java`, let those workflows finish before rebuilding the games images, or trigger `build games` manually afterwards.

Downloads during the build (rcon-cli, bercon, GE-Proton) are pinned and checked against checksums.

## Support

Need help or want to request a feature? Join the [Caloptreyx Discord](https://discord.gg/4qjMWU7S8x).

## License

MIT, see [LICENSE](LICENSE). Parts are derived from [pterodactyl/yolks](https://github.com/pterodactyl/yolks) and [Ptero-Eggs/yolks](https://github.com/Ptero-Eggs/yolks).
