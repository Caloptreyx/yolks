# Core Keeper dedicated server runtime: steamcmd:debian plus the virtual display the server needs.
# The server generates parts of the world on the GPU path, so it runs under Xvfb (see the game's
# _launch.sh); keeping Xvfb here avoids adding ~300 MB to the shared steamcmd:debian image.
FROM        ghcr.io/caloptreyx/steamcmd:debian

LABEL       org.opencontainers.image.source="https://github.com/Caloptreyx/yolks"
LABEL       org.opencontainers.image.description="Core Keeper dedicated server runtime with Xvfb"
LABEL       org.opencontainers.image.licenses=MIT

USER        root
RUN         apt-get update \
            && apt-get install -y --no-install-recommends xvfb xauth libxi6 \
            && rm -rf /var/lib/apt/lists/*
USER        container
