#!/bin/bash
set -euo pipefail

# Only set SCRIPT_DIR if not already set (e.g., when sourced)
if [ -z "${SCRIPT_DIR:-}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Ensure we're in the preload directory, not lib
if [[ "$SCRIPT_DIR" == */lib ]]; then
    SCRIPT_DIR="$(dirname "$SCRIPT_DIR")"
fi

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/toolchain.sh"

# Global variables for tls-preloader source
TLS_PRELOADER_REPO="https://github.com/f0rw4rd/tls-preloader.git"
TLS_PRELOADER_SRC_DIR=""
TLS_PRELOADER_GIT_COMMIT=""

# Function to clone tls-preloader repository once
clone_tls_preloader() {
    if [ -n "$TLS_PRELOADER_SRC_DIR" ] && [ -d "$TLS_PRELOADER_SRC_DIR" ]; then
        # Already cloned
        return 0
    fi
    
    TLS_PRELOADER_SRC_DIR="/tmp/tls-preloader-src-$$"
    log "Cloning tls-preloader repository..."
    
    git clone --depth 1 "$TLS_PRELOADER_REPO" "$TLS_PRELOADER_SRC_DIR" || {
        log_error "Failed to clone tls-preloader repository"
        return 1
    }
    
    # Get the git commit hash
    TLS_PRELOADER_GIT_COMMIT=$(cd "$TLS_PRELOADER_SRC_DIR" && git rev-parse --short HEAD)
    log "Using tls-preloader commit: $TLS_PRELOADER_GIT_COMMIT"
    
    return 0
}

build_tls_noverify() {
    local arch="$1"
    local output_dir="/build/output-preload/glibc/$arch"
    
    if [ -f "$output_dir/libtlsnoverify.so" ]; then
        log "libtlsnoverify.so already built for $arch"
        return 0
    fi
    
    # Clone repository if not already done
    clone_tls_preloader || return 1
    
    log "Building tls-noverify for $arch..."
    
    ensure_toolchain "$arch" || {
        log_error "Toolchain not available for $arch"
        return 1
    }
    
    local toolchain_dir=$(get_toolchain_dir "$arch")
    local cross_compile=$(get_toolchain_prefix "$arch")
    local CC="${toolchain_dir}/bin/${cross_compile}-gcc"
    local STRIP="${toolchain_dir}/bin/${cross_compile}-strip"
    
    if [ ! -x "$CC" ]; then
        local actual_gcc=$(find "${toolchain_dir}/bin" -name "*-gcc" -type f -executable | grep -v ".br_real" | head -1)
        if [ -n "$actual_gcc" ]; then
            CC="$actual_gcc"
            log_debug "Using gcc: $CC"
        else
            log_error "No gcc found in ${toolchain_dir}/bin"
            return 1
        fi
    fi
    
    if [ ! -x "$STRIP" ]; then
        STRIP=$(find "${toolchain_dir}/bin" -name "*-strip" -type f -executable | head -1)
    fi
    
    # Build in the source directory
    cd "$TLS_PRELOADER_SRC_DIR"
    
    # Clean any previous build artifacts
    make clean >/dev/null 2>&1 || true
    
    log "Building libtlsnoverify.so using Makefile..."
    
    # Export CC and STRIP for the Makefile
    export CC="$CC"
    export STRIP="$STRIP"
    
    # Build using the Makefile
    make || {
        log_error "Make failed"
        make clean >/dev/null 2>&1 || true
        return 1
    }
    
    # Check if the library was built
    if [ ! -f "libtlsnoverify.so" ]; then
        log_error "libtlsnoverify.so was not created"
        make clean >/dev/null 2>&1 || true
        return 1
    fi
    
    # Copy to output directory
    mkdir -p "$output_dir"
    cp libtlsnoverify.so "$output_dir/"
    
    local size=$(ls -lh "$output_dir/libtlsnoverify.so" | awk '{print $5}')
    log "Successfully built libtlsnoverify.so for $arch ($size)"
    
    # Clean up build artifacts
    make clean >/dev/null 2>&1 || true
    
    return 0
}

build_tls_noverify_musl() {
    local arch="$1"
    local output_dir="/build/output-preload/musl/$arch"
    
    if [ -f "$output_dir/libtlsnoverify.so" ]; then
        log "libtlsnoverify.so already built for $arch (musl)"
        return 0
    fi
    
    # Clone repository if not already done
    clone_tls_preloader || return 1
    
    log "Building tls-noverify for $arch (musl)..."
    
    # For musl builds, we use the musl toolchain
    local toolchain_dir="/toolchains/$arch"
    if [ ! -d "$toolchain_dir" ]; then
        log_error "Musl toolchain not found for $arch"
        return 1
    fi
    
    local CC="${toolchain_dir}/bin/gcc"
    local STRIP="${toolchain_dir}/bin/strip"
    
    if [ ! -x "$CC" ]; then
        CC=$(find "${toolchain_dir}/bin" -name "*-gcc" -type f -executable | head -1)
        if [ -z "$CC" ]; then
            log_error "No gcc found in musl toolchain"
            return 1
        fi
    fi
    
    if [ ! -x "$STRIP" ]; then
        STRIP=$(find "${toolchain_dir}/bin" -name "*-strip" -type f -executable | head -1)
    fi
    
    # Build in the source directory
    cd "$TLS_PRELOADER_SRC_DIR"
    
    # Clean any previous build artifacts
    make clean >/dev/null 2>&1 || true
    
    log "Building libtlsnoverify.so using Makefile (musl)..."
    
    # Export CC and STRIP for the Makefile
    export CC="$CC"
    export STRIP="$STRIP"
    
    # Build using the Makefile
    make || {
        log_error "Make failed"
        make clean >/dev/null 2>&1 || true
        return 1
    }
    
    # Check if the library was built
    if [ ! -f "libtlsnoverify.so" ]; then
        log_error "libtlsnoverify.so was not created"
        make clean >/dev/null 2>&1 || true
        return 1
    fi
    
    # Copy to output directory
    mkdir -p "$output_dir"
    cp libtlsnoverify.so "$output_dir/"
    
    local size=$(ls -lh "$output_dir/libtlsnoverify.so" | awk '{print $5}')
    log "Successfully built libtlsnoverify.so for $arch (musl) ($size)"
    
    # Clean up build artifacts
    make clean >/dev/null 2>&1 || true
    
    return 0
}

# Cleanup function to remove cloned repository
cleanup_tls_preloader() {
    if [ -n "$TLS_PRELOADER_SRC_DIR" ] && [ -d "$TLS_PRELOADER_SRC_DIR" ]; then
        log_debug "Cleaning up tls-preloader source directory"
        rm -rf "$TLS_PRELOADER_SRC_DIR"
        TLS_PRELOADER_SRC_DIR=""
        TLS_PRELOADER_GIT_COMMIT=""
    fi
}

# Set trap to cleanup on exit
trap cleanup_tls_preloader EXIT

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <architecture|all>"
        echo "Architectures: x86_64 aarch64 arm32v7le i486 mips64le ppc64le riscv64 s390x"
        echo "               aarch64be mips64 armv5 armv6 ppc32 sparc64 sh4 mips32 mips32el"
        echo "               riscv32 microblazeel microblazebe nios2 openrisc arcle m68k"
        exit 1
    fi
    
    arch="$1"
    
    if [ "$arch" = "all" ]; then
        for a in x86_64 aarch64 arm32v7le i486 mips64le ppc64le riscv64 s390x \
                 aarch64be mips64 armv5 armv6 ppc32 sparc64 sh4 mips32 mips32el \
                 riscv32 microblazeel microblazebe nios2 openrisc arcle m68k; do
            build_tls_noverify "$a" || log_error "Failed to build for $a"
        done
    else
        build_tls_noverify "$arch"
    fi
fi