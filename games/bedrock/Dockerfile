# Minecraft Bedrock Dedicated Server runtime with automatic server updates on start.
FROM        debian:trixie-slim

LABEL       org.opencontainers.image.source="https://github.com/Caloptreyx/yolks"
LABEL       org.opencontainers.image.description="Minecraft Bedrock Dedicated Server runtime"
LABEL       org.opencontainers.image.licenses=MIT

ENV         DEBIAN_FRONTEND=noninteractive

RUN         apt-get update \
            && apt-get install -y --no-install-recommends \
                ca-certificates curl jq unzip iproute2 procps tini tzdata \
            && rm -rf /var/lib/apt/lists/* \
            && useradd -m -d /home/container -s /bin/bash container

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

STOPSIGNAL  SIGINT

COPY        --chmod=0755 ./entrypoint.sh /entrypoint.sh
COPY        --chmod=0755 ./bedrock-update.sh /usr/local/bin/bedrock-update
ENTRYPOINT  ["/usr/bin/tini", "-g", "--"]
CMD         ["/entrypoint.sh"]
