# Installation container for egg install scripts. Runs as root; Wings fixes file ownership afterwards.
FROM        alpine:latest

LABEL       org.opencontainers.image.source="https://github.com/Caloptreyx/yolks"
LABEL       org.opencontainers.image.description="Installer image for Calagopus/Pterodactyl egg install scripts"
LABEL       org.opencontainers.image.licenses=MIT

# SteamCMD is a 32-bit Linux application. Alpine uses musl instead of glibc,
# so gcompat is installed to provide the required glibc compatibility layer.
RUN         apk add --no-cache \
                ca-certificates \
                curl \
                wget \
                git \
                jq \
                tar \
                gzip \
                xz \
                bzip2 \
                unzip \
                zip \
                file \
                gcompat \
                libgcc \
                libstdc++

