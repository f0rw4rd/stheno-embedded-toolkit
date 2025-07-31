#!/bin/sh
# Build preload libraries with musl toolchains
# This runs inside the main Alpine container
set -e

# Default values
LIBS_TO_BUILD=""
ARCHS_TO_BUILD=""
DEBUG=""

# Parse arguments
while [ $# -gt 0 ]; do
    case $1 in
        -d|--debug)
            DEBUG=1
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
        shell-env|shell-helper|shell-bind|shell-reverse|shell-fifo)
            LIBS_TO_BUILD="$1"
            shift
            ;;
        x86_64|aarch64|arm32v7le|i486|mips64le|ppc64le|riscv64)
            ARCHS_TO_BUILD="$1"
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Default to all if not specified
[ -z "$LIBS_TO_BUILD" ] && LIBS_TO_BUILD="all"
[ -z "$ARCHS_TO_BUILD" ] && ARCHS_TO_BUILD="all"

# Expand "all"
if [ "$LIBS_TO_BUILD" = "all" ]; then
    LIBS_TO_BUILD="shell-env shell-helper shell-bind shell-reverse shell-fifo"
fi

if [ "$ARCHS_TO_BUILD" = "all" ]; then
    ARCHS_TO_BUILD="x86_64 aarch64 arm32v7le i486"
fi

echo "==================================="
echo "Preload Library Build with Musl"
echo "==================================="
echo "Libraries: $LIBS_TO_BUILD"
echo "Architectures: $ARCHS_TO_BUILD"
echo "==================================="
echo

# Function to build a library
build_preload_musl() {
    local lib="$1"
    local arch="$2"
    local output_dir="/build/output-preload/musl/$arch"
    local source="/build/preload-libs/${lib}.c"
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Check if already built
    if [ -f "$output_dir/${lib}.so" ]; then
        local size=$(ls -lh "$output_dir/${lib}.so" 2>/dev/null | awk '{print $5}')
        echo "[$arch] Already built: ${lib}.so ($size)"
        return 0
    fi
    
    # Get toolchain prefix
    local prefix=""
    case "$arch" in
        x86_64)      prefix="x86_64-linux-musl" ;;
        aarch64)     prefix="aarch64-linux-musl" ;;
        arm32v7le)   prefix="arm-linux-musleabihf" ;;
        i486)        prefix="i486-linux-musl" ;;
        mips64le)    prefix="mips64el-linux-musl" ;;
        ppc64le)     prefix="powerpc64le-linux-musl" ;;
        riscv64)     prefix="riscv64-linux-musl" ;;
        *)           echo "[$arch] Unknown architecture"; return 1 ;;
    esac
    
    # Check if toolchain exists
    local toolchain_dir="/build/toolchains/$arch"
    if [ ! -d "$toolchain_dir" ]; then
        echo "[$arch] Toolchain not found, building it first..."
        # Build a dummy tool to create the toolchain
        cd /build
        /scripts/build-unified.sh strace "$arch" >/dev/null 2>&1 || true
        
        if [ ! -d "$toolchain_dir" ]; then
            echo "[$arch] Failed to create toolchain"
            return 1
        fi
    fi
    
    local compiler="${toolchain_dir}/bin/${prefix}-gcc"
    local strip_cmd="${toolchain_dir}/bin/${prefix}-strip"
    
    if [ ! -x "$compiler" ]; then
        echo "[$arch] Compiler not found: $compiler"
        return 1
    fi
    
    echo "[$arch] Building ${lib}.so..."
    
    # Compilation flags
    local cflags="-fPIC -O2 -Wall -D_GNU_SOURCE -fno-strict-aliasing"
    local ldflags="-shared -Wl,-soname,${lib}.so"
    
    # Create temp directory
    local build_dir="/tmp/build-${lib}-${arch}-$$"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Compile
    if $compiler $cflags -c "$source" -o "${lib}.o" 2>&1; then
        # Link
        if $compiler $ldflags -o "${lib}.so" "${lib}.o" -ldl 2>&1; then
            # Strip
            $strip_cmd "${lib}.so" 2>/dev/null || true
            
            # Copy to output
            cp "${lib}.so" "$output_dir/" || {
                echo "[$arch] Failed to copy library"
                cd /
                rm -rf "$build_dir"
                return 1
            }
            
            # Show info
            local size=$(ls -lh "$output_dir/${lib}.so" 2>/dev/null | awk '{print $5}')
            echo "[$arch] Successfully built: ${lib}.so ($size)"
            
            cd /
            rm -rf "$build_dir"
            return 0
        else
            echo "[$arch] Link failed"
        fi
    else
        echo "[$arch] Compilation failed"
    fi
    
    cd /
    rm -rf "$build_dir"
    return 1
}

# Build each library for each architecture
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

echo "==================================="
echo "Build Summary"
echo "==================================="
echo "Total: $TOTAL"
echo "Successful: $SUCCESS"
echo "Failed: $FAILED"

exit $FAILED