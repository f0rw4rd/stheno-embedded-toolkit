#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/build_flags.sh"

BASH_VER="${BASH_VER:-5.2.15}"
BASH_URL="https://ftp.gnu.org/gnu/bash/bash-5.2.15.tar.gz"

build_bash() {
    local arch=$1
    local build_dir="/tmp/bash-build-${arch}-$$"
    local TOOL_NAME="bash"
    
    if check_binary_exists "$arch" "bash"; then
        return 0
    fi
    
    echo "[bash] Building for $arch..."
    
    setup_arch "$arch" || return 1
    
    download_source "bash" "$BASH_VER" "$BASH_URL" || return 1
    
    mkdir -p "$build_dir"
    cp -a /build/sources/bash-${BASH_VER} "$build_dir/"
    cd "$build_dir/bash-${BASH_VER}"
    
    local cflags=$(get_compile_flags "$arch" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch")
    
    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"

    ac_cv_func_strtoimax=no \
    ./configure \
        --host=$HOST \
        --enable-static-link \
        --without-bash-malloc \
        --disable-nls \
        --disable-rpath \
        --disable-net-redirections \
        --disable-progcomp \
        --disable-help-builtin || {
        echo "[bash] Configure failed for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    make -j$(nproc) || {
        echo "[bash] Build failed for $arch"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    $STRIP bash
    cp bash "/build/output/$arch/bash"
    
    local size=$(ls -lh "/build/output/$arch/bash" | awk '{print $5}')
    echo "[bash] Built successfully for $arch ($size)"
    
    cd /
    rm -rf "$build_dir"
    return 0
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    echo "Architectures: arm32v5le arm32v5lehf arm32v7le arm32v7lehf mips32v2le mips32v2be ppc32be ix86le x86_64 aarch64 mips64le ppc64le"
    exit 1
fi

arch=$1
build_bash "$arch"