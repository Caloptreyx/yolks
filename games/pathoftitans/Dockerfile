# Path of Titans server runtime: the server is updated through Alderon's AlderonGamesCmd on start, and the
# panel console is passed to the server over Source RCON (the server reads no console input).
FROM        ghcr.io/caloptreyx/steamcmd:debian

LABEL       org.opencontainers.image.source="https://github.com/Caloptreyx/yolks"
LABEL       org.opencontainers.image.description="Path of Titans server runtime"
LABEL       org.opencontainers.image.licenses=MIT

# AlderonGamesCmd does not update itself and Alderon publishes no versioned download, so the current
# build is pinned by checksum: when Alderon replaces it, this build fails until the checksum is updated.
ARG         ALDERON_CMD_SHA256=b1d428056195b25f849836d6035b7129333316b99abb2a9f4eb48eaf0841414d

USER        root
RUN         curl -fsSL -o /usr/local/bin/AlderonGamesCmd "https://launcher-cdn.alderongames.com/AlderonGamesCmd-Linux-x64" \
            && echo "${ALDERON_CMD_SHA256}  /usr/local/bin/AlderonGamesCmd" | sha256sum -c - \
            && chmod 0755 /usr/local/bin/AlderonGamesCmd
USER        container

# AlderonGamesCmd is a .NET single-file program: it needs no ICU for what it does, and unpacks its native
# libraries on first run into a folder it can write.
ENV         DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 \
            DOTNET_BUNDLE_EXTRACT_BASE_DIR=/home/container/.cache/dotnet

COPY        --chmod=0755 ./entrypoint.sh /entrypoint.sh
