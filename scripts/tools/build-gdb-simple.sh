#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/build_flags.sh"
source "$SCRIPT_DIR/../lib/build_helpers.sh"

GDB_VERSION="${GDB_VERSION:-15.2}"
GDB_URL="https://ftp.gnu.org/gnu/gdb/gdb-${GDB_VERSION}.tar.xz"

build_gdb_simple() {
    local arch=$1
    local build_dir=$(create_build_dir "gdb-simple" "$arch")
    local TOOL_NAME="gdb-simple"
    
    
    setup_arch "$arch" || return 1
    
    cd "$build_dir"
    
    download_source "gdb" "$GDB_VERSION" "$GDB_URL" || return 1
    tar xf /build/sources/gdb-${GDB_VERSION}.tar.xz
    cd gdb-${GDB_VERSION}
    
    local cflags=$(get_compile_flags "$arch" "$TOOL_NAME")
    local cxxflags=$(get_cxx_flags "$arch" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch")
    
    export CFLAGS="$cflags"
    export CXXFLAGS="$cxxflags"
    export LDFLAGS="$ldflags"
    
    ./configure \
        --host=$HOST \
        --disable-shared \
        --enable-static \
        --with-static-standard-libraries \
        --disable-gdbserver \
        --disable-tui \
        --disable-nls \
        --without-python \
        --without-guile \
        --without-lzma \
        --disable-source-highlight \
        --disable-werror || {
        log_tool_error "gdb-simple" "Configure failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    make -j$(nproc) || {
        log_tool_error "gdb-simple" "Build failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    if [ -f "gdb/gdb" ]; then
        $STRIP gdb/gdb
        mkdir -p "/build/output/$arch"
        cp gdb/gdb "/build/output/$arch/gdb-simple"
        log_tool "gdb-simple" "Built successfully for $arch"
        cleanup_build_dir "$build_dir"
        return 0
    else
        log_tool_error "gdb-simple" "Failed to build gdb for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    fi
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    exit 1
fi

arch=$1
build_gdb_simple "$arch"
