#!/bin/bash
# Minecraft Bedrock Dedicated Server entrypoint.
#
# Environment:
#   STARTUP          startup command from the panel; {{VAR}} is replaced with ${VAR} (required)
#   AUTO_UPDATE      1 (default) updates the server on start, 0 skips it
#   BEDROCK_VERSION  latest (default), preview or a fixed version such as 1.21.50.10

cd /home/container || exit 1

export TZ="${TZ:-UTC}"
INTERNAL_IP=$(ip route get 1 2>/dev/null | awk '{print $(NF-2); exit}')
export INTERNAL_IP

if [[ -z "${AUTO_UPDATE}" || "${AUTO_UPDATE}" == "1" ]]; then
    bedrock-update || echo "[bedrock-update] Update failed, starting the installed version."
fi

if [[ ! -x ./bedrock_server ]]; then
    echo "bedrock_server is missing. Reinstall the server, or turn Auto Update on."
    exit 1
fi

export LD_LIBRARY_PATH=.

MODIFIED_STARTUP=$(printf '%s' "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo ":/home/container$ ${MODIFIED_STARTUP}"

eval "${MODIFIED_STARTUP}"
