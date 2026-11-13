#!/bin/bash
# Hytale server entrypoint.
#
# The game files need a Hytale account, so they are downloaded here, where the console can show the
# downloader's login code, rather than in the installer. The downloader keeps its credentials in
# .hytale-downloader-credentials.json, so the browser login is only needed once.
#
# Environment:
#   STARTUP            startup command from the panel; {{VAR}} is replaced with ${VAR} (required)
#   AUTO_UPDATE        1 (default) checks for a new server version on start, 0 skips it
#   HYTALE_PATCHLINE   release (default) or pre-release

cd /home/container || exit 1

export TZ="${TZ:-UTC}"
INTERNAL_IP=$(ip route get 1 2>/dev/null | awk '{print $(NF-2); exit}')
export INTERNAL_IP

DOWNLOADER=./hytale-downloader/hytale-downloader-linux
PATCHLINE="${HYTALE_PATCHLINE:-release}"

if [[ ! -x "${DOWNLOADER}" ]]; then
    echo "The Hytale downloader is missing. Reinstall the server."
    exit 1
fi

if [[ ! -f Server/HytaleServer.jar ]] || [[ -z "${AUTO_UPDATE}" || "${AUTO_UPDATE}" == "1" ]]; then
    [[ -f Server/HytaleServer.jar ]] || echo "[hytale] First start: downloading the server. Log in with the code below if asked."
    # tee: the downloader's login prompt must reach the console, not just the captured version.
    available=$("${DOWNLOADER}" -skip-update-check -patchline "${PATCHLINE}" -print-version 2>&1 | tee /dev/stderr | tail -n 1)
    installed=$(cat .hytale-version 2>/dev/null)

    if [[ -f Server/HytaleServer.jar && -n "${installed}" && "${available}" == "${installed}" ]]; then
        echo "[hytale] Server ${installed} (${PATCHLINE}) is up to date."
    else
        # Downloaded next to the server: the container /tmp is a small tmpfs.
        if "${DOWNLOADER}" -skip-update-check -patchline "${PATCHLINE}" -download-path .hytale-server.zip \
            && unzip -q -o .hytale-server.zip -d .; then
            version=$("${DOWNLOADER}" -skip-update-check -patchline "${PATCHLINE}" -print-version 2>&1 | tail -n 1)
            echo "${version}" > .hytale-version
            echo "[hytale] Installed server ${version} (${PATCHLINE})."
        else
            echo "[hytale] Download failed."
        fi
        rm -f .hytale-server.zip
    fi
fi

if [[ ! -f Server/HytaleServer.jar || ! -f Assets.zip ]]; then
    echo "Server/HytaleServer.jar or Assets.zip is missing: the download did not complete. Check the log in above and restart."
    exit 1
fi

java -version

MODIFIED_STARTUP=$(printf '%s' "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo ":/home/container$ ${MODIFIED_STARTUP}"

eval "${MODIFIED_STARTUP}"
