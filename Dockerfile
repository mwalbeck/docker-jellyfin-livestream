FROM node:16.20.2-bullseye-slim@sha256:503446c15c6236291222f8192513c2eb56a02a8949cbadf4fe78cce19815c734 as web-builder

# renovate: datasource=github-tags depName=jellyfin/jellyfin-web versioning=semver
ENV JELLYFIN_WEB_VERSION v10.8.11

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

FROM mcr.microsoft.com/dotnet/sdk:6.0@sha256:1167d21bf2d6b0aeb9fce863a73e90defa9233574b74d9deabee0a714f15c951 as builder

# renovate: datasource=github-tags depName=jellyfin/jellyfin versioning=semver
ENV JELLYFIN_VERSION v10.8.11
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

WORKDIR /repo
COPY jellyfin_livestream.patch /

# because of changes in docker and systemd we need to not build in parallel at the moment
# see https://success.docker.com/article/how-to-reserve-resource-temporarily-unavailable-errors-due-to-tasksmax-setting
RUN set -ex; \
    git clone --branch $JELLYFIN_VERSION https://github.com/jellyfin/jellyfin.git .; \
    git apply /jellyfin_livestream.patch; \
    dotnet publish Jellyfin.Server --disable-parallel --configuration Release --output="/jellyfin" --self-contained --runtime linux-x64 -p:DebugSymbols=false -p:DebugType=none;

FROM debian:bullseye-slim@sha256:9bec46ecd98ce4bf8305840b021dda9b3e1f8494a0768c407e2b233180fa1466

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
