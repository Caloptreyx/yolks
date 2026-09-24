# SteamCMD runtime for Windows game servers, run through GE-Proton.
FROM        debian:trixie-slim

LABEL       org.opencontainers.image.source="https://github.com/Caloptreyx/yolks"
LABEL       org.opencontainers.image.description="SteamCMD runtime for Windows game servers using GE-Proton"
LABEL       org.opencontainers.image.licenses=MIT

ENV         DEBIAN_FRONTEND=noninteractive
SHELL       ["/bin/bash", "-o", "pipefail", "-c"]

# Bump PROTON_VERSION deliberately and retest the servers that use this image: Proton updates can
# change game behaviour. The build verifies the release's published sha512 checksum.
ARG         PROTON_VERSION=GE-Proton11-7
ARG         RCON_VERSION=0.10.3
ARG         RCON_SHA256=6962a641ebf9a5957bd0cda1b8acf3e34a23686ae709f6c6a14ac3898521a5cc

RUN         dpkg --add-architecture i386 \
            && apt-get update \
            && apt-get install -y --no-install-recommends \
                ca-certificates curl wget tar gzip xz-utils unzip cabextract file iproute2 procps tini tzdata locales \
                python3 dbus winbind xvfb xauth numactl \
                lib32gcc-s1 lib32stdc++6 libncurses6 libgdiplus libfreetype6 libfontconfig1 \
                libasound2t64 libpulse0 libgnutls30t64 libntlm0 \
            && rm -rf /var/lib/apt/lists/* \
            && cd /tmp \
            && curl -fsSLO "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_VERSION}/${PROTON_VERSION}-x86_64.tar.gz" \
            && curl -fsSLO "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_VERSION}/${PROTON_VERSION}-x86_64.sha512sum" \
            && sha512sum -c "${PROTON_VERSION}-x86_64.sha512sum" \
            && tar -xzf "${PROTON_VERSION}-x86_64.tar.gz" -C /usr/local/bin --strip-components=1 \
            && rm -f /tmp/GE-Proton* \
            && curl -fsSL -o /tmp/rcon.tar.gz "https://github.com/gorcon/rcon-cli/releases/download/v${RCON_VERSION}/rcon-${RCON_VERSION}-amd64_linux.tar.gz" \
            && echo "${RCON_SHA256}  /tmp/rcon.tar.gz" | sha256sum -c - \
            && tar -xzf /tmp/rcon.tar.gz -C /tmp \
            && install -m 0755 "/tmp/rcon-${RCON_VERSION}-amd64_linux/rcon" /usr/local/bin/rcon \
            && rm -rf /tmp/rcon* \
            && curl -fsSL -o /usr/local/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
            && chmod 0755 /usr/local/bin/winetricks \
            && rm -f /etc/machine-id /var/lib/dbus/machine-id \
            && dbus-uuidgen --ensure=/etc/machine-id && dbus-uuidgen --ensure \
            && sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen \
            && useradd -m -d /home/container -s /bin/bash container

LABEL       io.github.caloptreyx.proton-version=${PROTON_VERSION}

ENV         LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

STOPSIGNAL  SIGINT

COPY        --chmod=0755 ./entrypoint.sh /entrypoint.sh
ENTRYPOINT  ["/usr/bin/tini", "-g", "--"]
CMD         ["/entrypoint.sh"]
