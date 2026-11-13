# DayZ dedicated server runtime with server and Steam Workshop mod updates on startup.
# Based on the DayZ image by David Wolfe (Red-Thirten), MIT License.
FROM        debian:trixie-slim

LABEL       org.opencontainers.image.source="https://github.com/Caloptreyx/yolks"
LABEL       org.opencontainers.image.description="DayZ dedicated server runtime"
LABEL       org.opencontainers.image.licenses=MIT

ENV         DEBIAN_FRONTEND=noninteractive
SHELL       ["/bin/bash", "-o", "pipefail", "-c"]

# BattlEye RCon client for owners (`bercon`); the project moved its CLI to WoozyMasta/bercon-cli.
ARG         BERCON_VERSION=v0.5.0
ARG         BERCON_SHA256=35677b3965c5b1dd7250102748b5a8a10047b33aefaab6205bbdebbf21905f4a

# libssl-dev provides the unversioned libssl.so the server loads.
RUN         dpkg --add-architecture i386 \
            && apt-get update \
            && apt-get install -y --no-install-recommends \
                ca-certificates curl tar gzip iproute2 procps tini tzdata locales gettext-base \
                libssl-dev lib32gcc-s1 libsdl2-2.0-0 libsdl2-2.0-0:i386 \
                libstdc++6 libstdc++6:i386 lib32stdc++6 libcap2 libnss-wrapper \
            && rm -rf /var/lib/apt/lists/* \
            && curl -fsSL -o /usr/local/bin/bercon "https://github.com/WoozyMasta/bercon-cli/releases/download/${BERCON_VERSION}/bercon-cli-linux-amd64" \
            && echo "${BERCON_SHA256}  /usr/local/bin/bercon" | sha256sum -c - \
            && chmod 0755 /usr/local/bin/bercon \
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
