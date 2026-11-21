# Luanti (formerly Minetest) dedicated server runtime: the headless luantiserver binary, built from the
# tagged release because Debian 13 only packages an older version. Games and mods are installed into
# the server files by the egg.
FROM        debian:trixie-slim AS build

ARG         LUANTI_VERSION=5.18.0

SHELL       ["/bin/bash", "-o", "pipefail", "-c"]
RUN         apt-get update \
            && apt-get install -y --no-install-recommends \
                ca-certificates git g++ make cmake ninja-build \
                libsqlite3-dev libcurl4-openssl-dev zlib1g-dev libzstd-dev libluajit-5.1-dev libgmp-dev \
                libjsoncpp-dev libssl-dev \
            && rm -rf /var/lib/apt/lists/*
RUN         git clone --depth 1 --branch "${LUANTI_VERSION}" https://github.com/luanti-org/luanti.git /src \
            && cmake -S /src -B /build -G Ninja -DCMAKE_BUILD_TYPE=Release \
                -DBUILD_CLIENT=FALSE -DBUILD_SERVER=TRUE -DBUILD_UNITTESTS=FALSE -DRUN_IN_PLACE=FALSE \
                -DENABLE_GETTEXT=FALSE -DENABLE_POSTGRESQL=FALSE -DENABLE_LEVELDB=FALSE -DENABLE_REDIS=FALSE \
                -DENABLE_PROMETHEUS=FALSE -DENABLE_SPATIAL=FALSE -DENABLE_CURSES=FALSE \
                -DCMAKE_INSTALL_PREFIX=/opt/luanti \
            && cmake --build /build \
            && cmake --install /build \
            && /opt/luanti/bin/luantiserver --version

FROM        ghcr.io/caloptreyx/steamcmd:debian

LABEL       org.opencontainers.image.source="https://github.com/Caloptreyx/yolks"
LABEL       org.opencontainers.image.description="Luanti dedicated server runtime"
LABEL       org.opencontainers.image.licenses=MIT

USER        root
RUN         apt-get update \
            && apt-get install -y --no-install-recommends \
                libsqlite3-0 zlib1g libzstd1 libluajit-5.1-2 libgmp10 libjsoncpp26 \
            && rm -rf /var/lib/apt/lists/*
COPY        --from=build /opt/luanti /opt/luanti
RUN         ln -s /opt/luanti/bin/luantiserver /usr/local/bin/luantiserver \
            && luantiserver --version
USER        container
