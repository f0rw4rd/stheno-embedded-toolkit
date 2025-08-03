#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/build_flags.sh"
source "$SCRIPT_DIR/../lib/build_helpers.sh"

GDB_VERSION="${GDB_VERSION:-11.2}"
GDB_URL="https://ftp.gnu.org/gnu/gdb/gdb-${GDB_VERSION}.tar.xz"

build_gdbserver() {
    local arch=$1
    local build_dir=$(create_build_dir "gdbserver" "$arch")
    local TOOL_NAME="gdbserver"
    
    if check_binary_exists "$arch" "gdbserver"; then
        return 0
    fi
    
    
    setup_arch "$arch" || return 1
    
    download_source "gdb" "$GDB_VERSION" "$GDB_URL" || return 1
    
    cd "$build_dir"
    
    tar xf /build/sources/gdb-${GDB_VERSION}.tar.xz
    cd gdb-${GDB_VERSION}
    
    local cflags=$(get_compile_flags "$arch" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch")
    
    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"

    ./configure \
        --host=$HOST \
        --target=$HOST \
        --prefix=/usr \
        --disable-gdb \
        --enable-gdbserver \
        --disable-gdbtk \
        --disable-tui \
        --disable-werror \
        --without-x \
        --disable-sim \
        --without-lzma \
        --without-python \
        --without-guile \
        --without-gmp \
        --without-mpfr \
        --disable-inprocess-agent \
        --disable-nls \
        --without-expat \
        --disable-source-highlight || {
        log_tool_error "gdbserver" "Configure failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    make -j$(nproc) all-gdbserver MAKEINFO=true || {
        log_tool_error "gdbserver" "Build failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    $STRIP gdbserver/gdbserver
    cp gdbserver/gdbserver "/build/output/$arch/gdbserver"
    
    local size=$(ls -lh "/build/output/$arch/gdbserver" | awk '{print $5}')
    log_tool "gdbserver" "Built successfully for $arch ($size)"
    
    cleanup_build_dir "$build_dir"
    return 0
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    echo "Architectures: arm32v5le arm32v5lehf arm32v7le arm32v7lehf mips32v2le mips32v2be ppc32be ix86le x86_64 aarch64 mips64le ppc64le"
    exit 1
fi

arch=$1
build_gdbserver "$arch"