FROM        debian:bullseye-slim

LABEL       author="David Wolfe" maintainer="rehlmgaming@gmail.com"

LABEL       org.opencontainers.image.source="https://github.com/pterodactyl/yolks"
LABEL       org.opencontainers.image.licenses=MIT

ENV         DEBIAN_FRONTEND noninteractive

RUN         useradd -m -d /home/container -s /bin/bash container

RUN         ln -s /home/container/ /nonexistent

ENV         USER=container HOME=/home/container

## Update base packages
RUN         apt update \
            && apt upgrade -y

## Install dependencies
RUN         dpkg --add-architecture i386 \
            apt install -y curl lib32gcc-s1 ca-certificates libsdl2-2.0-0

## Configure locale
RUN         update-locale lang=en_US.UTF-8 \
            && dpkg-reconfigure --frontend noninteractive locales


WORKDIR     /home/container

COPY        ./entrypoint.sh /entrypoint.sh
CMD         [ "/bin/bash", "/entrypoint.sh" ]

