FROM        debian:bullseye-slim

LABEL       author="David Wolfe" maintainer="rehlmgaming@gmail.com"

LABEL       org.opencontainers.image.source="https://github.com/pterodactyl/yolks"
LABEL       org.opencontainers.image.licenses=MIT

ENV         DEBIAN_FRONTEND noninteractive

RUN         useradd -m -d /home/container -s /bin/bash container

RUN         ln -s /home/container/ /nonexistent

ENV         USER=container HOME=/home/container

## Update base packages
RUN         dpkg --add-architecture i386 \
                apt update \
                && apt upgrade -y

## Install dependencies
RUN         apt install -y curl ca-certificates libssl-dev lib32gcc-s1 libsdl2-2.0-0 libsdl2-2.0-0:i386 libtbb2 libtbb2:i386

## Configure locale
RUN         update-locale lang=en_US.UTF-8 \
                && dpkg-reconfigure --frontend noninteractive locales


WORKDIR     /home/container

COPY        ./entrypoint.sh /entrypoint.sh
CMD         [ "/bin/bash", "/entrypoint.sh" ]

