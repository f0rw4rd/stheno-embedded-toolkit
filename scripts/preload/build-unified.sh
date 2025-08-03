#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="/build"

DEBUG="${DEBUG:-}"
LIBS_TO_BUILD=""
ARCHS_TO_BUILD=""
LIBC_TYPE="${LIBC_TYPE:-glibc}"

ALL_LIBS=(libdesock shell-env shell-helper shell-bind shell-reverse shell-fifo)

ALL_ARCHS=(x86_64 aarch64 arm32v7le i486 mips64le ppc64le riscv64 s390x aarch64be mips64 armv5 armv6 ppc32 sparc64 sh4 mips32 mips32el riscv32 microblazeel microblazebe nios2 openrisc arcle m68k)

while [[ $# -gt 0 ]]; do
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
        libdesock|shell-env|shell-helper|shell-bind|shell-reverse|shell-fifo)
            LIBS_TO_BUILD="$1"
            shift
            ;;
        x86_64|aarch64|arm32v7le|i486|mips64le|ppc64le|riscv64|s390x|aarch64be|mips64|armv5|armv6|ppc32|sparc64|sh4|mips32|mips32el|riscv32|microblazeel|microblazebe|nios2|openrisc|arcle|m68k)
            ARCHS_TO_BUILD="$1"
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

[ -z "$LIBS_TO_BUILD" ] && LIBS_TO_BUILD="all"
[ -z "$ARCHS_TO_BUILD" ] && ARCHS_TO_BUILD="all"

if [ "$LIBS_TO_BUILD" = "all" ]; then
    LIBS_TO_BUILD="${ALL_LIBS[@]}"
fi

if [ "$ARCHS_TO_BUILD" = "all" ]; then
    ARCHS_TO_BUILD="${ALL_ARCHS[@]}"
fi

LIBS_ARRAY=($LIBS_TO_BUILD)
ARCHS_ARRAY=($ARCHS_TO_BUILD)

echo "Libc: ${LIBC_TYPE}"
echo "Debug: ${DEBUG:-0}"
echo

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/toolchain.sh"
source "$SCRIPT_DIR/lib/compile.sh"
source "$SCRIPT_DIR/lib/compile-musl.sh"

source "$SCRIPT_DIR/build-libdesock.sh"

TOTAL=$((${#LIBS_ARRAY[@]} * ${#ARCHS_ARRAY[@]}))
COUNT=0
FAILED=0

for lib in "${LIBS_ARRAY[@]}"; do
    for arch in "${ARCHS_ARRAY[@]}"; do
        COUNT=$((COUNT + 1))
        echo "[$COUNT/$TOTAL] Building $lib for $arch..."
        
        if [ "$lib" = "libdesock" ]; then
            if [ "$LIBC_TYPE" = "musl" ]; then
                echo "[$COUNT/$TOTAL] ⚠ Skipping libdesock for musl (only glibc supported)"
                continue
            fi
            if build_libdesock "$arch"; then
                echo "[$COUNT/$TOTAL] ✓ Successfully built $lib for $arch"
            else
                echo "[$COUNT/$TOTAL] ✗ Failed to build $lib for $arch"
                FAILED=$((FAILED + 1))
            fi
        else
            if [ "$LIBC_TYPE" = "musl" ]; then
                if build_preload_library_musl "$lib" "$arch"; then
                    echo "[$COUNT/$TOTAL] ✓ Successfully built $lib for $arch with musl"
                else
                    echo "[$COUNT/$TOTAL] ✗ Failed to build $lib for $arch with musl"
                    FAILED=$((FAILED + 1))
                fi
            else
                if build_preload_library "$lib" "$arch"; then
                    echo "[$COUNT/$TOTAL] ✓ Successfully built $lib for $arch with glibc"
                else
                    echo "[$COUNT/$TOTAL] ✗ Failed to build $lib for $arch with glibc"
                    FAILED=$((FAILED + 1))
                fi
            fi
        fi
        echo
    done
done

echo "Build Summary"
echo "Total: $TOTAL"
echo "Successful: $((TOTAL - FAILED))"
echo "Failed: $FAILED"

exit $FAILED