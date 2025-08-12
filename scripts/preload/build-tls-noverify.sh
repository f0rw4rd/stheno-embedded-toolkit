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

build_tls_noverify() {
    local arch="$1"
    local output_dir="/build/output-preload/glibc/$arch"
    local build_dir="/tmp/tls-noverify-build-${arch}-$$"
    
    if [ -f "$output_dir/tls-noverify.so" ]; then
        log "tls-noverify.so already built for $arch"
        return 0
    fi
    
    log "Building tls-noverify for $arch..."
    
    ensure_toolchain "$arch" || {
        log_error "Toolchain not available for $arch"
        return 1
    }
    
    local toolchain_dir=$(get_toolchain_dir "$arch")
    local cross_compile=$(get_toolchain_prefix "$arch")
    local CC="${toolchain_dir}/bin/${cross_compile}-gcc"
    
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
    
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Copy source file
    cp "/build/preload-libs/tls-noverify.c" .
    
    # Compilation flags
    local CFLAGS="-fPIC -O2 -fomit-frame-pointer -fno-stack-protector -Wall -Wextra"
    CFLAGS="$CFLAGS -D_GNU_SOURCE"
    CFLAGS="$CFLAGS -DSHARED"
    
    # Add architecture-specific flags
    case "$arch" in
        x86_64|aarch64*|ppc64le|s390x|mips64*|sparc64|riscv64)
            # 64-bit architectures
            ;;
        *)
            # 32-bit architectures
            ;;
    esac
    
    local LDFLAGS="-shared -ldl -lpthread"
    
    log "Compiling tls-noverify..."
    $CC $CFLAGS -c tls-noverify.c -o tls-noverify.o || {
        log_error "Compilation failed"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    $CC $LDFLAGS -o tls-noverify.so tls-noverify.o || {
        log_error "Linking failed"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    mkdir -p "$output_dir"
    cp tls-noverify.so "$output_dir/"
    
    local strip_cmd="${toolchain_dir}/bin/${cross_compile}-strip"
    if [ ! -x "$strip_cmd" ]; then
        strip_cmd=$(find "${toolchain_dir}/bin" -name "*-strip" -type f -executable | head -1)
    fi
    if [ -x "$strip_cmd" ]; then
        $strip_cmd "$output_dir/tls-noverify.so" 2>/dev/null || true
    fi
    
    local size=$(ls -lh "$output_dir/tls-noverify.so" | awk '{print $5}')
    log "Successfully built tls-noverify.so for $arch ($size)"
    
    cd /
    rm -rf "$build_dir"
    
    return 0
}

build_tls_noverify_musl() {
    local arch="$1"
    local output_dir="/build/output-preload/musl/$arch"
    local build_dir="/tmp/tls-noverify-build-${arch}-musl-$$"
    
    if [ -f "$output_dir/tls-noverify.so" ]; then
        log "tls-noverify.so already built for $arch (musl)"
        return 0
    fi
    
    log "Building tls-noverify for $arch (musl)..."
    
    # For musl builds, we use the musl toolchain
    local toolchain_dir="/toolchains/$arch"
    if [ ! -d "$toolchain_dir" ]; then
        log_error "Musl toolchain not found for $arch"
        return 1
    fi
    
    local CC="${toolchain_dir}/bin/gcc"
    if [ ! -x "$CC" ]; then
        CC=$(find "${toolchain_dir}/bin" -name "*-gcc" -type f -executable | head -1)
        if [ -z "$CC" ]; then
            log_error "No gcc found in musl toolchain"
            return 1
        fi
    fi
    
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Copy source file
    cp "/build/preload-libs/tls-noverify.c" .
    
    # Compilation flags for musl
    local CFLAGS="-fPIC -O2 -Wall -Wextra"
    CFLAGS="$CFLAGS -D_GNU_SOURCE"
    CFLAGS="$CFLAGS -DSHARED"
    
    local LDFLAGS="-shared -ldl -lpthread"
    
    log "Compiling tls-noverify.so (musl)..."
    $CC $CFLAGS -c tls-noverify.c -o tls-noverify.o || {
        log_error "Compilation failed"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    $CC $LDFLAGS -o tls-noverify.so tls-noverify.o || {
        log_error "Linking failed"
        cd /
        rm -rf "$build_dir"
        return 1
    }
    
    mkdir -p "$output_dir"
    cp tls-noverify.so "$output_dir/"
    
    # Strip the binary
    local strip_cmd="${toolchain_dir}/bin/strip"
    if [ -x "$strip_cmd" ]; then
        $strip_cmd "$output_dir/tls-noverify.so" 2>/dev/null || true
    fi
    
    local size=$(ls -lh "$output_dir/tls-noverify.so" | awk '{print $5}')
    log "Successfully built tls-noverify.so for $arch (musl) ($size)"
    
    cd /
    rm -rf "$build_dir"
    
    return 0
}

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