#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/build_helpers.sh"
source "$SCRIPT_DIR/lib/arch_map.sh"

LIBS_TO_BUILD=""
ARCHS_TO_BUILD=""

while [ $# -gt 0 ]; do
    case $1 in
        -d|--debug)
            shift
            ;;
        all)
            if [ -z "$LIBS_TO_BUILD" ]; then
                LIBS_TO_BUILD="all"
            elif [ -z "$ARCHS_TO_BUILD" ]; then
                ARCHS_TO_BUILD="all"
            fi
            shift
            ;;
        shell-env|shell-helper|shell-bind|shell-reverse|shell-fifo|tls-noverify)
            LIBS_TO_BUILD="$1"
            shift
            ;;
        x86_64|aarch64|arm32v7le|i486|mips64le|ppc64le|riscv64|s390x|aarch64be|mips64|armv5|armv6|ppc32|sparc64|sh4|mips32|mips32el|riscv32|microblazeel|microblazebe|nios2|openrisc|arcle|m68k)
            ARCHS_TO_BUILD="$1"
            shift
            ;;
        *)
            log_error "Unknown argument: $1"
            exit 1
            ;;
    esac
done

[ -z "$LIBS_TO_BUILD" ] && LIBS_TO_BUILD="all"
[ -z "$ARCHS_TO_BUILD" ] && ARCHS_TO_BUILD="all"

if [ "$LIBS_TO_BUILD" = "all" ]; then
    LIBS_TO_BUILD="shell-env shell-helper shell-bind shell-reverse shell-fifo tls-noverify"
fi

if [ "$ARCHS_TO_BUILD" = "all" ]; then
    # Use the same architectures as glibc for consistency
    ARCHS_TO_BUILD="x86_64 aarch64 arm32v7le i486 mips64le ppc64le riscv64 s390x aarch64be mips64 armv5 armv6 ppc32 sparc64 sh4 mips32 mips32el riscv32 microblazeel microblazebe nios2 openrisc arcle m68k"
fi

build_preload_musl() {
    local lib="$1"
    local arch="$2"
    local output_dir="/build/output-preload/musl/$arch"
    
    # Special handling for tls-noverify - use the dedicated build script
    if [ "$lib" = "tls-noverify" ]; then
        # Source the tls-noverify build script
        source "/build/scripts/preload/build-tls-noverify.sh"
        # Call the musl build function
        build_tls_noverify_musl "$arch"
        return $?
    fi
    
    # Regular preload library handling
    local source="/build/preload-libs/${lib}.c"
    
    mkdir -p "$output_dir"
    
    if [ -f "$output_dir/${lib}.so" ]; then
        local size=$(get_binary_size "$output_dir/${lib}.so")
        log_tool "$arch" "Already built: ${lib}.so ($size)"
        return 0
    fi
    
    local prefix=""
    case "$arch" in
        x86_64)      prefix="x86_64-linux-musl" ;;
        aarch64)     prefix="aarch64-linux-musl" ;;
        aarch64be)   prefix="aarch64_be-linux-musl" ;;
        arm32v7le)   prefix="armv7l-linux-musleabihf" ;;
        i486)        prefix="i486-linux-musl" ;;
        mips64le)    prefix="mips64el-linux-musl" ;;
        ppc64le)     prefix="powerpc64le-linux-musl" ;;
        riscv64)     prefix="riscv64-linux-musl" ;;
        s390x)       prefix="s390x-linux-musl" ;;
        mips64)      prefix="mips64-linux-musl" ;;
        armv5)       prefix="arm-linux-musleabi" ;;
        armv6)       prefix="armv6-linux-musleabihf" ;;
        ppc32)       prefix="powerpc-linux-musl" ;;
        sparc64)     prefix="sparc64-linux-musl" ;;
        sh4)         prefix="sh4-linux-musl" ;;
        mips32)      prefix="mips-linux-musl" ;;
        mips32el)    prefix="mipsel-linux-musl" ;;
        riscv32)     prefix="riscv32-linux-musl" ;;
        microblazeel) prefix="microblazeel-linux-musl" ;;
        microblazebe) prefix="microblaze-linux-musl" ;;
        nios2)       prefix="nios2-linux-musl" ;;
        openrisc)    prefix="or1k-linux-musl" ;;
        arcle)       prefix="arc-linux-musl" ;;
        m68k)        prefix="m68k-linux-musl" ;;
        *)           log_tool "$arch" "Unknown architecture"; return 1 ;;
    esac
    
    local toolchain_dir="/build/toolchains/${prefix}-cross"
    if [ ! -d "$toolchain_dir" ]; then
        log_tool "$arch" "Toolchain not found, building it first..."
        cd /build
        /scripts/build-unified.sh strace "$arch" >/dev/null 2>&1 || true
        
        if [ ! -d "$toolchain_dir" ]; then
            log_tool "$arch" "Failed to create toolchain"
            return 1
        fi
    fi
    
    local compiler="${toolchain_dir}/bin/${prefix}-gcc"
    local strip_cmd="${toolchain_dir}/bin/${prefix}-strip"
    
    if [ ! -x "$compiler" ]; then
        log_tool "$arch" "Compiler not found: $compiler"
        return 1
    fi
    
    log_tool "$arch" "Building ${lib}.so..."
    
    local cflags="-fPIC -O2 -Wall -D_GNU_SOURCE -fno-strict-aliasing"
    local ldflags="-shared -Wl,-soname,${lib}.so"
    
    local build_dir="/tmp/build-${lib}-${arch}-$$"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Add pthread for tls-noverify
    local extra_libs="-ldl"
    if [ "$lib" = "tls-noverify" ]; then
        extra_libs="-ldl -lpthread"
    fi
    
    if $compiler $cflags -c "$source" -o "${lib}.o" 2>&1; then
        if $compiler $ldflags -o "${lib}.so" "${lib}.o" $extra_libs 2>&1; then
            $strip_cmd "${lib}.so" 2>/dev/null || true
            
            cp "${lib}.so" "$output_dir/" || {
                log_tool "$arch" "Failed to copy library"
                cleanup_build_dir "$build_dir"
                return 1
            }
            
            local size=$(get_binary_size "$output_dir/${lib}.so")
            log_tool "$arch" "Successfully built: ${lib}.so ($size)"
            
            cleanup_build_dir "$build_dir"
            return 0
        else
            log_tool "$arch" "Link failed"
        fi
    else
        log_tool "$arch" "Compilation failed"
    fi
    
    cleanup_build_dir "$build_dir"
    return 1
}

TOTAL=0
SUCCESS=0
FAILED=0

for lib in $LIBS_TO_BUILD; do
    for arch in $ARCHS_TO_BUILD; do
        TOTAL=$((TOTAL + 1))
        if build_preload_musl "$lib" "$arch"; then
            SUCCESS=$((SUCCESS + 1))
        else
            FAILED=$((FAILED + 1))
        fi
        echo
    done
done

log_info "Total: $TOTAL"
log_info "Successful: $SUCCESS"
log_error "Failed: $FAILED"

exit $FAILED