# Horizon server runtime: horizon-server is downloaded and updated on start, and its game files are
# prepared with the Java 25 runtime of the base image.
FROM        ghcr.io/caloptreyx/java:25

LABEL       org.opencontainers.image.source="https://github.com/Caloptreyx/yolks"
LABEL       org.opencontainers.image.description="Horizon (Minecraft: Java Edition) server runtime"
LABEL       org.opencontainers.image.licenses=MIT

USER        root
RUN         apt-get update \
            && apt-get install -y --no-install-recommends jq \
            && rm -rf /var/lib/apt/lists/*
USER        container

COPY        --chmod=0755 ./entrypoint.sh /entrypoint.sh
COPY        --chmod=0755 ./horizon-update.sh /usr/local/bin/horizon-update
