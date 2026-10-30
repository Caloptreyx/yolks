#!/bin/bash
# Horizon (Minecraft: Java Edition 26.3) entrypoint.
#
# Installs or updates horizon-server and prepares its game files (horizon-update), writes the panel's
# settings into server.toml with `horizon-server config set`, which checks them as the server does, adds
# the listed players, then runs the startup command.
#
# Environment:
#   STARTUP              startup command from the panel; {{VAR}} is replaced with ${VAR} (required)
#   SERVER_PORT          the allocation's port, written to server.port on every start
#   HORIZON_VERSION, AUTO_UPDATE, PREPARE_GAME_FILES   see horizon-update
#   ONLINE_MODE, WHITELIST            true or false: server.online_mode, server.whitelist
#   MOTD, MAX_PLAYERS, VIEW_DISTANCE  server.motd, server.max_players, server.view_distance
#   GAME_MODE, DIFFICULTY             world.game_mode, world.difficulty
#   BACKUP_INTERVAL                   backups.every (30m, 6h, 1d...; 0 turns Horizon's backups off)
#   PREGEN                            true or false: properties.horizon-pregen (the `pregen` command)
#   WHITELIST_PLAYERS, OPS            names, separated by commas: whitelisted / made operators
# A setting left empty is not touched, so server.toml keeps whatever it says.

cd /home/container || exit 1

export TZ="${TZ:-UTC}"
INTERNAL_IP=$(ip route get 1 2>/dev/null | awk '{print $(NF-2); exit}')
export INTERNAL_IP
# Horizon's own update check tells owners to run `horizon-server update`, which needs Horizon's
# installer layout; horizon-update does the updates here.
export HORIZON_NO_UPDATE_CHECK=1

HORIZON=./horizon/horizon-server

horizon-update || echo "[horizon-update] Update failed, starting the installed release if there is one."

if [[ ! -x "${HORIZON}" ]]; then
    echo "horizon-server is missing: the download failed. Check the messages above and restart."
    exit 1
fi
installed=$(sed -n 2p horizon/.horizon-release 2>/dev/null)
if [[ "${PREPARE_GAME_FILES:-1}" != "0" && "$(cat horizon/.local/horizon-client/.horizon-prepared 2>/dev/null)" != "${installed}" ]]; then
    echo "The game files are not prepared for Horizon ${installed}: check the messages above and restart."
    exit 1
fi

# server.toml, written without the EULA: the panel asks for it on the first start, as for vanilla. A
# vanilla server.properties already here is imported.
if [[ ! -f server.toml ]]; then
    if [[ -f server.properties ]]; then
        "${HORIZON}" import server.properties || exit 1
    else
        : > .horizon-empty.properties
        "${HORIZON}" import .horizon-empty.properties || exit 1
        rm -f .horizon-empty.properties
    fi
fi

settings=("server.port=${SERVER_PORT:-25565}")
add() { [[ -n "$2" ]] && settings+=("$1=$2"); }
add server.online_mode "${ONLINE_MODE}"
add server.whitelist "${WHITELIST}"
add server.motd "${MOTD}"
add server.max_players "${MAX_PLAYERS}"
add server.view_distance "${VIEW_DISTANCE}"
add world.game_mode "${GAME_MODE}"
add world.difficulty "${DIFFICULTY}"
add backups.every "${BACKUP_INTERVAL}"
add properties.horizon-pregen "${PREGEN}"
if ! "${HORIZON}" config set "${settings[@]}" >/dev/null; then
    echo "A setting from the panel was refused (above): fix it in the server's Startup settings."
    exit 1
fi

# After online_mode: the names are looked up as accounts in online mode, offline UUIDs otherwise.
for name in ${WHITELIST_PLAYERS//,/ }; do
    "${HORIZON}" whitelist add "${name}" >/dev/null || echo "Could not whitelist ${name}."
done
for name in ${OPS//,/ }; do
    "${HORIZON}" op "${name}" >/dev/null || echo "Could not make ${name} an operator."
done

MODIFIED_STARTUP=$(printf '%s' "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo ":/home/container$ ${MODIFIED_STARTUP}"

eval "${MODIFIED_STARTUP}"
