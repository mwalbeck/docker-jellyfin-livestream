FROM node:14.18.3-bullseye-slim@sha256:a9f0e5666de84b193ca5e5d79388bc57c7e3a8130e1ed7bb170c28ef6152fdbe as web-builder

# renovate: datasource=github-tags depName=jellyfin/jellyfin-web versioning=semver
ENV JELLYFIN_WEB_VERSION v10.7.7

WORKDIR /jellyfin-web

RUN set -ex; \
    apt-get update; \
    apt-get install --no-install-recommends -y \
        git \
        ca-certificates \
    ; \
    git clone --branch $JELLYFIN_WEB_VERSION https://github.com/jellyfin/jellyfin-web.git .; \
    npm install; \
    npm run build:production; \
    mv dist /dist;

FROM mcr.microsoft.com/dotnet/sdk:5.0.405-bullseye-slim@sha256:e77405dd87c57f947313f45937770d6519e2e094e279ebcd35e4f606bd7db7c9 as builder

# renovate: datasource=github-tags depName=jellyfin/jellyfin versioning=semver
ENV JELLYFIN_VERSION v10.7.7
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

WORKDIR /repo
COPY jellyfin_livestream.patch /

# because of changes in docker and systemd we need to not build in parallel at the moment
# see https://success.docker.com/article/how-to-reserve-resource-temporarily-unavailable-errors-due-to-tasksmax-setting
RUN set -ex; \
    git clone --branch $JELLYFIN_VERSION https://github.com/jellyfin/jellyfin.git .; \
    git apply /jellyfin_livestream.patch; \
    dotnet publish Jellyfin.Server --disable-parallel --configuration Release --output="/jellyfin" --self-contained --runtime linux-x64 "-p:DebugSymbols=false;DebugType=none";

FROM debian:bullseye-slim@sha256:d5cd7e54530a8523168473a2dcc30215f2c863bfa71e09f77f58a085c419155b

SHELL [ "/bin/bash", "-exo", "pipefail", "-c" ]

COPY --from=builder /jellyfin /jellyfin
COPY --from=web-builder /dist /jellyfin/jellyfin-web

# Install dependencies:
RUN apt-get update; \
    apt-get install --no-install-recommends -y \
        ca-certificates \
        gnupg \
        curl \
        apt-transport-https \
    ; \
    curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key | apt-key add -; \
    echo "deb [arch=amd64] https://repo.jellyfin.org/debian bullseye main" | tee /etc/apt/sources.list.d/jellyfin.list; \
    apt-get update; \
    apt-get install --no-install-recommends -y \
        jellyfin-ffmpeg \
        openssl \
        locales \
    ; \
    apt-get purge --autoremove -y \
        gnupg \
        wget \
        apt-transport-https; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /cache /config /media; \
    chmod 777 /cache /config /media; \
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen; \
    locale-gen;

ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en

COPY start-transcode.sh /usr/local/bin/start-transcode

EXPOSE 8096
VOLUME /cache /config /media
ENTRYPOINT ["./jellyfin/jellyfin", \
    "--datadir", "/config", \
    "--cachedir", "/cache", \
    "--ffmpeg", "/usr/lib/jellyfin-ffmpeg/ffmpeg"]
