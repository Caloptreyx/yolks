# Yolks

Docker images for the [Caloptreyx game eggs](https://github.com/Caloptreyx/game-eggs), for Calagopus and Pterodactyl. They are rebuilt every Monday so Debian security updates get in, and on every change pushed to `main`.

| Image | Used for | Base |
|-------|----------|------|
| `ghcr.io/caloptreyx/installers:debian` | Egg install scripts | Debian 13 |
| `ghcr.io/caloptreyx/steamcmd:debian` | Linux game servers updated through SteamCMD (7 Days to Die, Palworld) | Debian 13 |
| `ghcr.io/caloptreyx/steamcmd:proton` | Windows game servers through GE-Proton (ARK: Survival Ascended) | Debian 13 |
| `ghcr.io/caloptreyx/games:rust` | Rust, with WebRCON console and Oxide/Carbon | Debian 13, Node.js 24 LTS |
| `ghcr.io/caloptreyx/games:dayz` | DayZ, with Workshop mod updates | Debian 13 |

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

## Publishing

The GitHub Actions workflows push to `ghcr.io/caloptreyx`. New packages on GHCR are private: after the first build, set each package (`installers`, `steamcmd`, `games`) to **Public** in its package settings so Wings can pull it without credentials.

Downloads during the build (rcon-cli, bercon, GE-Proton) are pinned and checked against checksums.

## License

MIT, see [LICENSE](LICENSE). Parts are derived from [pterodactyl/yolks](https://github.com/pterodactyl/yolks) and [Ptero-Eggs/yolks](https://github.com/Ptero-Eggs/yolks).
