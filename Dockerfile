FROM        --platform=$TARGETOS/$TARGETARCH ubuntu:22.04

LABEL       author="David Wolfe (Red-Thirten)" maintainer="rehlmgaming@gmail.com"

LABEL       org.opencontainers.image.source="https://github.com/parkervcp/yolks"
LABEL       org.opencontainers.image.licenses=MIT

ENV         DEBIAN_FRONTEND=noninteractive

# Install Dependencies
RUN         dpkg --add-architecture i386 \
            && apt-get update \
            && apt-get upgrade -y \
            && apt-get install -y ca-certificates curl lib32gcc-s1 libsdl2-2.0-0 libsdl2-2.0-0:i386 libcurl4:i386 git unzip zip tar jq

## Setup user and working directory
RUN         useradd -m -d /home/container -s /bin/bash container
USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

COPY        ./entrypoint.sh /entrypoint.sh
CMD         [ "/bin/bash", "/entrypoint.sh" ]
