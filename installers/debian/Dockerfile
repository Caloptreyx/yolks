# Installation container for egg install scripts. Runs as root; Wings fixes file ownership afterwards.
FROM        debian:trixie-slim

LABEL       org.opencontainers.image.source="https://github.com/Caloptreyx/yolks"
LABEL       org.opencontainers.image.description="Installer image for Calagopus/Pterodactyl egg install scripts"
LABEL       org.opencontainers.image.licenses=MIT

ENV         DEBIAN_FRONTEND=noninteractive

# SteamCMD is 32-bit and needs the i386 runtime libraries. SDL2 is left out on purpose: on Debian 13 it
# pulls in the Mesa/LLVM graphics stack (~400 MB) only to silence a SteamCMD warning.
RUN         dpkg --add-architecture i386 \
            && apt-get update \
            && apt-get install -y --no-install-recommends \
                ca-certificates curl wget git jq tar gzip xz-utils bzip2 unzip zip file \
                lib32gcc-s1 lib32stdc++6 \
            && rm -rf /var/lib/apt/lists/*
