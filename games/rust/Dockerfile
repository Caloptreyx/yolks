# Rust dedicated server runtime with a WebRCON console wrapper and optional Oxide/Carbon.

# Node.js and the wrapper's WebSocket dependency come from the official Node LTS image.
FROM        node:24-trixie-slim AS node
RUN         npm install --omit=dev --prefix /opt/wrapper ws@8

FROM        debian:trixie-slim

LABEL       org.opencontainers.image.source="https://github.com/Caloptreyx/yolks"
LABEL       org.opencontainers.image.description="Rust dedicated server runtime"
LABEL       org.opencontainers.image.licenses=MIT

ENV         DEBIAN_FRONTEND=noninteractive

RUN         dpkg --add-architecture i386 \
            && apt-get update \
            && apt-get install -y --no-install-recommends \
                ca-certificates curl tar gzip unzip iproute2 procps tini tzdata \
                lib32gcc-s1 lib32stdc++6 libgdiplus \
            && rm -rf /var/lib/apt/lists/* \
            && useradd -m -d /home/container -s /bin/bash container

COPY        --from=node /usr/local/bin/node /usr/local/bin/node
COPY        --from=node /opt/wrapper/node_modules /node_modules

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

COPY        --chmod=0755 ./entrypoint.sh /entrypoint.sh
COPY        ./wrapper.js /wrapper.js
ENTRYPOINT  ["/usr/bin/tini", "-g", "--"]
CMD         ["/entrypoint.sh"]
