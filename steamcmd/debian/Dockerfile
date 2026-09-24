# SteamCMD runtime for native Linux game servers.
FROM        debian:trixie-slim

LABEL       org.opencontainers.image.source="https://github.com/Caloptreyx/yolks"
LABEL       org.opencontainers.image.description="SteamCMD runtime for Linux game servers"
LABEL       org.opencontainers.image.licenses=MIT

ENV         DEBIAN_FRONTEND=noninteractive
SHELL       ["/bin/bash", "-o", "pipefail", "-c"]

ARG         RCON_VERSION=0.10.3
ARG         RCON_SHA256=6962a641ebf9a5957bd0cda1b8acf3e34a23686ae709f6c6a14ac3898521a5cc

# Runtime tools used by eggs: telnet and rcon for server consoles, perl/grep/sed for config edits.
# SDL2 is left out on purpose: on Debian 13 it pulls in the Mesa/LLVM graphics stack (~400 MB).
RUN         dpkg --add-architecture i386 \
            && apt-get update \
            && apt-get install -y --no-install-recommends \
                ca-certificates curl tar gzip xz-utils unzip iproute2 procps tini tzdata locales \
                inetutils-telnet netcat-openbsd perl xdg-user-dirs \
                lib32gcc-s1 lib32stdc++6 lib32z1 libstdc++6:i386 \
                libcurl4t64 libcurl3t64-gnutls:i386 libfontconfig1 libatomic1 \
            && rm -rf /var/lib/apt/lists/* \
            && curl -fsSL -o /tmp/rcon.tar.gz "https://github.com/gorcon/rcon-cli/releases/download/v${RCON_VERSION}/rcon-${RCON_VERSION}-amd64_linux.tar.gz" \
            && echo "${RCON_SHA256}  /tmp/rcon.tar.gz" | sha256sum -c - \
            && tar -xzf /tmp/rcon.tar.gz -C /tmp \
            && install -m 0755 "/tmp/rcon-${RCON_VERSION}-amd64_linux/rcon" /usr/local/bin/rcon \
            && rm -rf /tmp/rcon* \
            && sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen \
            && useradd -m -d /home/container -s /bin/bash container

ENV         LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

STOPSIGNAL  SIGINT

COPY        --chmod=0755 ./entrypoint.sh /entrypoint.sh
ENTRYPOINT  ["/usr/bin/tini", "-g", "--"]
CMD         ["/entrypoint.sh"]
