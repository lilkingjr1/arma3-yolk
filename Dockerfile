FROM        debian:bullseye-slim

LABEL       author="David Wolfe" maintainer="rehlmgaming@gmail.com"

LABEL       org.opencontainers.image.source="https://github.com/pterodactyl/yolks"
LABEL       org.opencontainers.image.licenses=MIT

ENV         DEBIAN_FRONTEND noninteractive

## Update base packages and install dependencies
RUN         dpkg --add-architecture i386 \
                && apt update \
                && apt upgrade -y \
                && apt install -y \
                    curl \
                    locales \
                    ca-certificates \
                    libssl-dev \
                    lib32gcc-s1 \
                    libsdl2-2.0-0 \
                    libsdl2-2.0-0:i386 \
                    libstdc++6 \
                    libstdc++6:i386 \
                    lib32stdc++6 \
                    libtbb2 \
                    libtbb2:i386

## Configure locale
RUN         update-locale lang=en_US.UTF-8 \
                && dpkg-reconfigure --frontend noninteractive locales

## Setup user and working directory
RUN         useradd -u 997 -m -d /home/container -s /bin/bash container
RUN         ln -s /home/container/ /nonexistent
USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

## Copy over and execute entrypoint.sh
COPY        ./entrypoint.sh /entrypoint.sh
CMD         [ "/bin/bash", "/entrypoint.sh" ]
