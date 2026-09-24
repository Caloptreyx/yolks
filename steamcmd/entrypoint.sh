#!/bin/bash
# SteamCMD runtime entrypoint, shared by steamcmd:debian and steamcmd:proton.
# Derived from pterodactyl/yolks (MIT, Copyright (c) 2021 Matthew Penner).
#
# Environment (all optional unless noted):
#   STARTUP            startup command from the panel; {{VAR}} is replaced with ${VAR} (required)
#   SRCDS_APPID        Steam app id; enables updates and the Proton prefix
#   AUTO_UPDATE        1 (default) updates the server through SteamCMD on start, 0 skips it
#   STEAM_USER/STEAM_PASS/STEAM_AUTH   Steam login, anonymous when unset
#   WINDOWS_INSTALL    1 downloads the Windows depot
#   SRCDS_BETAID/SRCDS_BETAPASS, INSTALL_FLAGS, VALIDATE=1, HLDS_GAME, UPDATE_STEAMWORKS=1

cd /home/container || exit 1

# Give the container a moment to settle before networking is used.
sleep 1

export TZ="${TZ:-UTC}"
INTERNAL_IP=$(ip route get 1 2>/dev/null | awk '{print $(NF-2); exit}')
export INTERNAL_IP

# Proton needs a prefix per app.
if [[ -x /usr/local/bin/proton ]]; then
    if [[ -z "${SRCDS_APPID}" ]]; then
        echo "SRCDS_APPID must be set to run a server with Proton."
        exit 1
    fi
    export STEAM_COMPAT_CLIENT_INSTALL_PATH="/home/container/.steam/steam"
    export STEAM_COMPAT_DATA_PATH="/home/container/.steam/steam/steamapps/compatdata/${SRCDS_APPID}"
    mkdir -p "${STEAM_COMPAT_DATA_PATH}"
fi

STEAM_USER="${STEAM_USER:-anonymous}"
if [[ "${STEAM_USER}" == "anonymous" ]]; then
    STEAM_PASS=""
    STEAM_AUTH=""
fi

if [[ -z "${AUTO_UPDATE}" || "${AUTO_UPDATE}" == "1" ]] && [[ -n "${SRCDS_APPID}" ]]; then
    if [[ ! -x ./steamcmd/steamcmd.sh ]]; then
        echo "SteamCMD is missing from the server files, skipping the update. Reinstall the server to restore it."
    else
        app_update="+app_update ${SRCDS_APPID}"
        [[ -n "${SRCDS_BETAID}" ]] && app_update+=" -beta ${SRCDS_BETAID}"
        [[ -n "${SRCDS_BETAPASS}" ]] && app_update+=" -betapassword ${SRCDS_BETAPASS}"
        [[ -n "${INSTALL_FLAGS}" ]] && app_update+=" ${INSTALL_FLAGS}"
        [[ "${VALIDATE}" == "1" ]] && app_update+=" validate"

        args=(+force_install_dir /home/container)
        [[ "${WINDOWS_INSTALL}" == "1" ]] && args+=(+@sSteamCmdForcePlatformType windows)
        args+=(+login "${STEAM_USER}" "${STEAM_PASS}" "${STEAM_AUTH}")
        [[ -n "${HLDS_GAME}" ]] && args+=(+app_set_config 90 mod "${HLDS_GAME}")
        args+=("${app_update}")
        [[ "${UPDATE_STEAMWORKS}" == "1" ]] && args+=(+app_update 1007)
        args+=(+quit)

        ./steamcmd/steamcmd.sh "${args[@]}"
    fi
fi

# Keep Steam credentials away from the server process.
unset STEAM_USER STEAM_PASS STEAM_AUTH

# Quoted so the command keeps its spacing and nothing in it is glob-expanded before eval.
MODIFIED_STARTUP=$(printf '%s' "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo ":/home/container$ ${MODIFIED_STARTUP}"

eval "${MODIFIED_STARTUP}"
