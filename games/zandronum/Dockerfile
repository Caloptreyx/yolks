# Zandronum (multiplayer Doom) server runtime. The official Linux build of zandronum-server is linked
# against SDL 1.2 and libjpeg 8, even though the server never opens a window. Debian 13 ships SDL 1.2
# (through sdl12-compat) but only libjpeg 6.2, so libjpeg 8 comes from Ubuntu's libjpeg-turbo8. The
# server binary and the WADs are installed into the server files by the egg.
FROM        ubuntu:24.04 AS jpeg
RUN         apt-get update \
            && apt-get install -y --no-install-recommends libjpeg-turbo8 \
            && mkdir -p /out \
            && cp -a /usr/lib/x86_64-linux-gnu/libjpeg.so.8* /out/

FROM        ghcr.io/caloptreyx/steamcmd:debian

LABEL       org.opencontainers.image.source="https://github.com/Caloptreyx/yolks"
LABEL       org.opencontainers.image.description="Zandronum server runtime"
LABEL       org.opencontainers.image.licenses=MIT

USER        root
RUN         apt-get update \
            && apt-get install -y --no-install-recommends libsdl1.2-compat libbz2-1.0 zlib1g libssl3t64 \
            && rm -rf /var/lib/apt/lists/*
COPY        --from=jpeg /out/ /usr/local/lib/
RUN         ldconfig
USER        container
