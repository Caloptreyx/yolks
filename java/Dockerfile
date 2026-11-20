# Java runtime for Minecraft and other Java servers: Eclipse Temurin JRE on Debian 13.
# Build with --build-arg JAVA_VERSION=8|11|17|21|25.
ARG         JAVA_VERSION=25
FROM        eclipse-temurin:${JAVA_VERSION}-jre AS jre

FROM        debian:trixie-slim

ARG         JAVA_VERSION
LABEL       org.opencontainers.image.source="https://github.com/Caloptreyx/yolks"
LABEL       org.opencontainers.image.description="Eclipse Temurin ${JAVA_VERSION} JRE runtime"
LABEL       org.opencontainers.image.licenses=MIT

ENV         DEBIAN_FRONTEND=noninteractive

# fontconfig/libfreetype6: map and image rendering plugins use Java 2D.
RUN         apt-get update \
            && apt-get install -y --no-install-recommends \
                ca-certificates curl tar gzip unzip git iproute2 procps tini tzdata locales \
                fontconfig libfreetype6 \
            && rm -rf /var/lib/apt/lists/* \
            && sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen \
            && useradd -m -d /home/container -s /bin/bash container

COPY        --from=jre /opt/java/openjdk /opt/java/openjdk
ENV         JAVA_HOME=/opt/java/openjdk
ENV         PATH=/opt/java/openjdk/bin:$PATH

# CVE-2026-114938 ("Java4Shell"): the AVX-512 Base64 decoder of JDK 17 and later can write past
# its output buffer. Turning the Base64 intrinsics off closes it until the patched JDK is in the
# image, whatever flags the startup command passes. The java launcher of JDK 9+ reads
# JDK_JAVA_OPTIONS; Java 8 ignores it (it lacks the flag, and the bug).
ENV         JDK_JAVA_OPTIONS=-XX:-UseBASE64Intrinsics

ENV         LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

STOPSIGNAL  SIGINT

COPY        --chmod=0755 ./entrypoint.sh /entrypoint.sh
ENTRYPOINT  ["/usr/bin/tini", "-g", "--"]
CMD         ["/entrypoint.sh"]
