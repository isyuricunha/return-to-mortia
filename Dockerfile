FROM ghcr.io/ptero-eggs/yolks:wine_latest

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        cabextract \
        crudini \
        xvfb \
        lib32gcc-s1 \
        p7zip-full \
        unzip \
        tar \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sSL -o /usr/local/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
    && chmod +x /usr/local/bin/winetricks

WORKDIR /mnt/server

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/mnt/server"]

EXPOSE 7777/udp

ENTRYPOINT ["/entrypoint.sh"]
