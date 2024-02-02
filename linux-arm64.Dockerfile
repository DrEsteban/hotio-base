ARG UPSTREAM_IMAGE
ARG UPSTREAM_DIGEST_ARM64

FROM alpine AS builder
ARG UNRAR_VER=6.2.12
RUN apk --update --no-cache add \
    autoconf \
    automake \
    binutils \
    build-base \
    cmake \
    cppunit-dev \
    curl-dev \
    libtool \
    linux-headers \
    zlib-dev \
# Install unrar from source
&& cd /tmp \
&& wget https://www.rarlab.com/rar/unrarsrc-${UNRAR_VER}.tar.gz -O /tmp/unrar.tar.gz \
&& tar -xzf /tmp/unrar.tar.gz \
&& cd unrar \
&& make -f makefile \
&& install -Dm 755 unrar /usr/bin/unrar


FROM ${UPSTREAM_IMAGE}@${UPSTREAM_DIGEST_ARM64}

ARG IMAGE_STATS
ARG BUILD_ARCHITECTURE
ENV IMAGE_STATS=${IMAGE_STATS} BUILD_ARCHITECTURE=${BUILD_ARCHITECTURE} \
    APP_DIR="/app" CONFIG_DIR="/config" PUID="1000" PGID="1000" UMASK="002" TZ="Etc/UTC" \
    XDG_CONFIG_HOME="${CONFIG_DIR}/.config" XDG_CACHE_HOME="${CONFIG_DIR}/.cache" XDG_DATA_HOME="${CONFIG_DIR}/.local/share" \
    LANG="en_US.UTF-8" LANGUAGE="en_US:en" LC_ALL="en_US.UTF-8" \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 S6_SERVICES_GRACETIME=180000 S6_STAGE2_HOOK="/init-hook" \
    VPN_ENABLED="false" VPN_PROVIDER="generic" VPN_LAN_NETWORK="" VPN_CONF="wg0" VPN_ADDITIONAL_PORTS="" VPN_AUTO_PORT_FORWARD="true" PRIVOXY_ENABLED="false" \
    VPN_PIA_USER="" VPN_PIA_PASS="" VPN_PIA_PREFERRED_REGION=""

VOLUME ["${CONFIG_DIR}"]

ENTRYPOINT ["/init"]

# install packages
RUN apk add --no-cache tzdata shadow bash curl wget jq grep sed coreutils findutils python3 unzip p7zip ca-certificates util-linux-misc bind-tools
RUN apk add --no-cache privoxy iptables ip6tables iproute2 openresolv wireguard-tools ipcalc && \
    apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/testing wireguard-go && \
    apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community libnatpmp figlet

COPY --from=builder /usr/bin/unrar /usr/bin/

# https://github.com/just-containers/s6-overlay/releases
ARG S6_VERSION=3.1.6.2
RUN curl -fsSL "https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-noarch.tar.xz" | tar Jpxf - -C / && \
    curl -fsSL "https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-aarch64.tar.xz" | tar Jpxf - -C / && \
    curl -fsSL "https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-symlinks-noarch.tar.xz" | tar Jpxf - -C / && \
    curl -fsSL "https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-symlinks-arch.tar.xz" | tar Jpxf - -C /

# make folders
RUN mkdir "${APP_DIR}" && \
    mkdir "${CONFIG_DIR}" && \
# create user
    useradd -u 1000 -U -d "${CONFIG_DIR}" -s /bin/false hotio && \
    usermod -G users hotio

ARG PIA_VERSION
RUN mkdir "${APP_DIR}/pia-scripts" && \
    wget -O - "https://github.com/pia-foss/manual-connections/archive/${PIA_VERSION}.tar.gz" | tar xzf - -C "${APP_DIR}/pia-scripts" --strip-components=1 && \
    chmod -R u=rwX,go=rX "${APP_DIR}/pia-scripts"

COPY root/ /
RUN chmod +x /init-hook
