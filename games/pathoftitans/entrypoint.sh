#!/bin/bash
# Path of Titans entrypoint.
#
# Updates the server with AlderonGamesCmd, then runs the startup command. The server reads no console
# input, so lines typed in the panel console are sent to it over Source RCON (rcon, on 127.0.0.1).
#
# Environment:
#   STARTUP        startup command from the panel; {{VAR}} is replaced with ${VAR} (required)
#   AG_AUTH_TOKEN  Alderon Games hosting token (required); the server reads it from the environment too
#   AUTO_UPDATE    1 (default) updates the server on start, 0 only installs it when it is missing
#   BETA_BRANCH    production (default) or demo-public-test
#   SERVER_GUID    the server's GUID; empty: one is generated once and kept in .pathoftitans-guid
#   SERVER_PORT    the game port; RCON_PORT defaults to it + 2, Path of Titans' own default
#   RCON_PASSWORD  empty: a random one for each start, which only the console uses

cd /home/container || exit 1

export TZ="${TZ:-UTC}"
INTERNAL_IP=$(ip route get 1 2>/dev/null | awk '{print $(NF-2); exit}')
export INTERNAL_IP

SERVER_BIN=./PathOfTitans/Binaries/Linux/PathOfTitansServer-Linux-Shipping
BRANCH="${BETA_BRANCH:-production}"

if [[ -z "${AG_AUTH_TOKEN}" ]]; then
    echo "The Auth Token is empty. Generate one at https://alderongames.com/oauth/hosting-token with the Alderon"
    echo "Games account that owns Path of Titans, put it in the server's Startup settings and restart."
    exit 1
fi
export AG_AUTH_TOKEN

if [[ "${AUTO_UPDATE:-1}" != "0" || ! -f "${SERVER_BIN}" ]]; then
    echo "[pot-update] Updating Path of Titans (${BRANCH})..."
    if AlderonGamesCmd --game path-of-titans --server true --beta-branch "${BRANCH}" \
        --auth-token "${AG_AUTH_TOKEN}" --install-dir /home/container; then
        echo "[pot-update] Path of Titans is up to date."
    else
        echo "[pot-update] Update failed (check the Auth Token and Beta Branch), starting the installed version."
    fi
fi

if [[ ! -f "${SERVER_BIN}" ]]; then
    echo "The Path of Titans server is not installed: the download failed. Check the messages above and restart."
    exit 1
fi
[[ -x "${SERVER_BIN}" ]] || chmod +x "${SERVER_BIN}"

if [[ -z "${SERVER_GUID}" ]]; then
    [[ -s .pathoftitans-guid ]] || cat /proc/sys/kernel/random/uuid > .pathoftitans-guid
    SERVER_GUID=$(cat .pathoftitans-guid)
fi
export SERVER_GUID
export RCON_PORT="${RCON_PORT:-$(( ${SERVER_PORT:-7777} + 2 ))}"
if [[ -z "${RCON_PASSWORD}" ]]; then
    RCON_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
fi
export RCON_PASSWORD

# The panel console: every line becomes one RCON command. Started first so it reads the container's
# stdin (fd 3); the server runs in the foreground, so the panel's stop signal reaches it unchanged.
exec 3<&0
(
    while IFS= read -r line <&3; do
        [[ -n "${line// /}" ]] || continue
        rcon -a "127.0.0.1:${RCON_PORT}" -p "${RCON_PASSWORD}" "${line}" \
            || echo "[console] Could not send '${line}' over RCON: the server may still be starting."
    done
) &
console=$!

MODIFIED_STARTUP=$(printf '%s' "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo ":/home/container$ ${MODIFIED_STARTUP}"

eval "${MODIFIED_STARTUP}" < /dev/null
status=$?
kill "${console}" 2>/dev/null
exit "${status}"
