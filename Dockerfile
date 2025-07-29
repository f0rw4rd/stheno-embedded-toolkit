FROM alpine:3.18

# Install build dependencies
RUN apk update && apk add --no-cache \
    build-base \
    gcc g++ make cmake automake autoconf libtool \
    pkgconf \
    git wget curl \
    tar gzip bzip2 xz \
    patch \
    python3 py3-pip \
    bison flex \
    texinfo \
    gawk \
    bc \
    ncurses-dev \
    openssl-dev \
    zlib-dev \
    expat-dev \
    libffi-dev \
    gmp-dev mpc1-dev mpfr-dev \
    ccache \
    bash \
    coreutils \
    linux-headers \
    musl-dev \
    readline-dev \
    libpcap-dev

# Set ccache configuration
ENV CCACHE_DIR=/root/.ccache
ENV CCACHE_MAXSIZE=5G
ENV CCACHE_COMPRESS=1
ENV PATH="/usr/lib/ccache:$PATH"

# Create build directory structure (will be mounted as volume)
RUN mkdir -p /build

# Sources will be mounted from host - no need to download in image

# Create necessary directories
RUN mkdir -p /build/sources /build/toolchains /build/deps-cache /build/output /build/logs

WORKDIR /build

# Default command
CMD ["/bin/bash"]