FROM node:14.18.1-buster@sha256:6bdb0edee68fba64cfbf6640f48c484bbc93dcbceedcc428b0bc489f1675b332 as web-builder

# renovate: datasource=github-tags depName=jellyfin/jellyfin-web versioning=semver
ENV JELLYFIN_WEB_VERSION v10.7.7

WORKDIR /jellyfin-web

RUN set -ex; \
    git clone --branch $JELLYFIN_WEB_VERSION https://github.com/jellyfin/jellyfin-web.git .; \
    npm install; \
    npm run build:production; \
    mv dist /dist;

FROM mcr.microsoft.com/dotnet/sdk:5.0.402-buster-slim@sha256:5d6aff01076f269ecf5b9d9e5d708d1cb21636636f54c47d929efde9e89bb197 as builder

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

FROM debian:buster-slim@sha256:544c93597c784cf68dbe492ef35c00de7f4f6a990955c7144a40b20d86a3475f

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
    echo "deb [arch=amd64] https://repo.jellyfin.org/debian buster main" | tee /etc/apt/sources.list.d/jellyfin.list; \
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
