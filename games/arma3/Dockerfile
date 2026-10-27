# Arma 3 dedicated server runtime with server and Steam Workshop mod updates on startup.
FROM        debian:trixie-slim

LABEL       org.opencontainers.image.source="https://github.com/Caloptreyx/yolks"
LABEL       org.opencontainers.image.description="Arma 3 dedicated server runtime"
LABEL       org.opencontainers.image.licenses=MIT

ENV         DEBIAN_FRONTEND=noninteractive
SHELL       ["/bin/bash", "-o", "pipefail", "-c"]

# lib32gcc-s1/lib32stdc++6: SteamCMD and the 32-bit server. libtbbmalloc2: the server's allocator.
# libnss-wrapper for both architectures: the server needs a passwd entry for its UID, and the
# 32-bit server binary needs the 32-bit wrapper. jq reads the Steam Workshop API.
RUN         dpkg --add-architecture i386 \
            && apt-get update \
            && apt-get install -y --no-install-recommends \
                ca-certificates curl tar gzip iproute2 procps tini tzdata locales gettext-base jq \
                lib32gcc-s1 lib32stdc++6 libstdc++6 libstdc++6:i386 \
                libtbbmalloc2 libtbbmalloc2:i386 libnss-wrapper libnss-wrapper:i386 \
            && rm -rf /var/lib/apt/lists/* \
            && sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen \
            && useradd -m -d /home/container -s /bin/bash container

# The entrypoint writes these at runtime for whatever UID the container runs as.
ENV         NSS_WRAPPER_PASSWD=/tmp/passwd NSS_WRAPPER_GROUP=/tmp/group
COPY        ./passwd.template /passwd.template

ENV         LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

STOPSIGNAL  SIGINT

COPY        --chmod=0755 ./entrypoint.sh /entrypoint.sh
ENTRYPOINT  ["/usr/bin/tini", "-g", "--"]
CMD         ["/entrypoint.sh"]
