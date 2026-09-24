#!/bin/bash
# Rust dedicated server entrypoint. Derived from pterodactyl/yolks (MIT).
#
# Environment:
#   STARTUP      startup command from the panel (required)
#   AUTO_UPDATE  1 (default) updates the server through SteamCMD on start, 0 skips it
#   FRAMEWORK    vanilla (default), oxide or carbon; the framework is updated on every start
#   RCON_PORT, RCON_PASS, RCON_IP   WebRCON connection used by the console wrapper

cd /home/container || exit 1

INTERNAL_IP=$(ip route get 1 2>/dev/null | awk '{print $(NF-2); exit}')
export INTERNAL_IP

if [[ -z "${AUTO_UPDATE}" || "${AUTO_UPDATE}" == "1" ]]; then
    if [[ -x ./steamcmd/steamcmd.sh ]]; then
        ./steamcmd/steamcmd.sh +force_install_dir /home/container +login anonymous +app_update 258550 +quit
    else
        echo "SteamCMD is missing from the server files, skipping the update. Reinstall the server to restore it."
    fi
else
    echo "Auto update is disabled, starting the server without updating."
fi

# The startup command is expanded here and run through a shell again by the wrapper; eggs quote
# text values as "\"{{VAR}}\"" to survive both passes.
MODIFIED_STARTUP=$(eval echo "$(printf '%s' "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')")
echo ":/home/container$ ${MODIFIED_STARTUP}"

# OXIDE=1 is the older way of selecting Oxide.
[[ "${OXIDE}" == "1" && "${FRAMEWORK}" != "carbon" ]] && FRAMEWORK=oxide

case "${FRAMEWORK}" in
    carbon)
        echo "Updating Carbon..."
        if curl -fsSL "https://github.com/CarbonCommunity/Carbon.Core/releases/download/production_build/Carbon.Linux.Release.tar.gz" | tar -xz; then
            echo "Done updating Carbon!"
        else
            echo "Could not update Carbon, starting with the installed version."
        fi
        export DOORSTOP_ENABLED=1
        export DOORSTOP_TARGET_ASSEMBLY="$(pwd)/carbon/managed/Carbon.Preloader.dll"
        MODIFIED_STARTUP="LD_PRELOAD=$(pwd)/libdoorstop.so ${MODIFIED_STARTUP}"
        ;;
    oxide)
        echo "Updating uMod..."
        if curl -fsSL -o umod.zip "https://github.com/OxideMod/Oxide.Rust/releases/latest/download/Oxide.Rust-linux.zip" \
            && unzip -o -q umod.zip; then
            echo "Done updating uMod!"
        else
            echo "Could not update uMod, starting with the installed version."
        fi
        rm -f umod.zip
        ;;
esac

export LD_LIBRARY_PATH="$(pwd)/RustDedicated_Data/Plugins/x86_64:$(pwd)"

exec node /wrapper.js "${MODIFIED_STARTUP}"
