#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/build_flags.sh"
source "$SCRIPT_DIR/../lib/build_helpers.sh"

DROPBEAR_VERSION="${DROPBEAR_VERSION:-2022.83}"
DROPBEAR_URL="https://matt.ucc.asn.au/dropbear/releases/dropbear-${DROPBEAR_VERSION}.tar.bz2"

build_dropbear() {
    local arch=$1
    local build_dir=$(create_build_dir "dropbear" "$arch")
    local TOOL_NAME="dropbear"
    
    if check_binary_exists "$arch" "dropbear"; then
        return 0
    fi
    
    
    setup_arch "$arch" || return 1
    
    download_source "dropbear" "$DROPBEAR_VERSION" "$DROPBEAR_URL" || return 1
    
    cd "$build_dir"
    tar xf /build/sources/dropbear-${DROPBEAR_VERSION}.tar.bz2
    cd dropbear-${DROPBEAR_VERSION}
    
    local cflags=$(get_compile_flags "$arch" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch")
    
    CFLAGS="$cflags" \
    LDFLAGS="$ldflags" \
    ./configure \
        --host=$HOST \
        --disable-zlib \
        --disable-syslog \
        --disable-lastlog \
        --disable-utmp \
        --disable-utmpx \
        --disable-wtmp \
        --disable-wtmpx \
        --disable-pututline \
        --disable-pututxline \
        --enable-static \
        || {
        log_tool_error "dropbear" "Configure failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    cat > localoptions.h << 'EOF'
/* Dropbear custom options for embedded systems */

/* Algorithms - disable weaker ones to save space */
EOF
    
    make -j$(nproc) PROGRAMS="dropbear dbclient dropbearkey scp" STATIC=1 || {
        log_tool_error "dropbear" "Build failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    $STRIP dropbear
    $STRIP dbclient
    $STRIP dropbearkey
    $STRIP scp
    
    cp dropbear "/build/output/$arch/dropbear"
    
    cp dbclient "/build/output/$arch/dbclient"
    cp dropbearkey "/build/output/$arch/dropbearkey"
    cp scp "/build/output/$arch/scp"
    
    cd "/build/output/$arch"
    ln -sf dbclient ssh
    
    local size=$(ls -lh dropbear | awk '{print $5}')
    log_tool "dropbear" "Built successfully for $arch"
    log_tool "dropbear" "  - dropbear (SSH server): $size"
    log_tool "dropbear" "  - dbclient (SSH client): $(ls -lh dbclient | awk '{print $5}')"
    log_tool "dropbear" "  - dropbearkey (key gen): $(ls -lh dropbearkey | awk '{print $5}')"
    log_tool "dropbear" "  - scp (secure copy): $(ls -lh scp | awk '{print $5}')"
    
    cleanup_build_dir "$build_dir"
    return 0
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    exit 1
fi

arch=$1
build_dropbear "$arch"