#!/bin/bash
# Java runtime entrypoint. Derived from pterodactyl/yolks (MIT).
#
# Environment:
#   STARTUP   startup command from the panel; {{VAR}} is replaced with ${VAR} (required)

cd /home/container || exit 1

sleep 1

export TZ="${TZ:-UTC}"
INTERNAL_IP=$(ip route get 1 2>/dev/null | awk '{print $(NF-2); exit}')
export INTERNAL_IP

java -version

MODIFIED_STARTUP=$(printf '%s' "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo ":/home/container$ ${MODIFIED_STARTUP}"

eval "${MODIFIED_STARTUP}"
