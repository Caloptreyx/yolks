# Hytale server runtime: Java 25 plus the game download on start (needs a Hytale account).
FROM        ghcr.io/caloptreyx/java:25

LABEL       org.opencontainers.image.source="https://github.com/Caloptreyx/yolks"
LABEL       org.opencontainers.image.description="Hytale server runtime"
LABEL       org.opencontainers.image.licenses=MIT

COPY        --chmod=0755 ./entrypoint.sh /entrypoint.sh
