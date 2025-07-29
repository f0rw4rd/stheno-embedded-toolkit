#!/bin/bash
# Build script for BusyBox
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/build_flags.sh"

BUSYBOX_VERSION="${BUSYBOX_VERSION:-1.36.1}"
BUSYBOX_URL="https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2"

build_busybox() {
    local arch=$1
    local build_dir="/tmp/busybox-build-${arch}-$$"
    local TOOL_NAME="busybox"
    
    # Check if binary already exists
    if check_binary_exists "$arch" "busybox"; then
        return 0
    fi
    
    echo "[busybox] Building for $arch..."
    
    # Setup architecture
    setup_arch "$arch" || return 1
    
    # Download source
    download_source "busybox" "$BUSYBOX_VERSION" "$BUSYBOX_URL" || return 1
    
    # Create build directory
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Extract source
    tar xf /build/sources/busybox-${BUSYBOX_VERSION}.tar.bz2
    cd busybox-${BUSYBOX_VERSION}
    
    # Configure for static build
    make defconfig
    
    # Enable static linking and disable shared libraries
    sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
    sed -i 's/CONFIG_BUILD_LIBBUSYBOX=y/# CONFIG_BUILD_LIBBUSYBOX is not set/' .config
    sed -i 's/CONFIG_FEATURE_SHARED_BUSYBOX=y/# CONFIG_FEATURE_SHARED_BUSYBOX is not set/' .config
    
    # Set cross compiler with centralized flags
    local cflags=$(get_compile_flags "$arch" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch")
    
    make ARCH="$CONFIG_ARCH" \
         CROSS_COMPILE="$CROSS_COMPILE" \
         CFLAGS="$cflags" \
         LDFLAGS="$ldflags" \
         -j$(nproc) || {
        echo "[busybox] Build failed for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    # Strip and copy binary
    $STRIP busybox
    cp busybox "/build/output/$arch/busybox"
    
    # Get size
    local size=$(ls -lh "/build/output/$arch/busybox" | awk '{print $5}')
    echo "[busybox] Built successfully for $arch ($size)"
    
    # Cleanup
    cd /
    rm -rf "$build_dir"
    return 0
}

# Main
if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    echo "Architectures: arm32v5le arm32v5lehf arm32v7le arm32v7lehf mips32v2le mips32v2be ppc32be ix86le x86_64 aarch64 mips64le ppc64le"
    exit 1
fi

arch=$1
build_busybox "$arch"