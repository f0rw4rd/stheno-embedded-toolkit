#!/bin/bash
# Common functions for preload library builds

# Source centralized logging from main scripts/lib
source /build/scripts/lib/logging.sh


# Create directory if it doesn't exist
ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || {
            log_error "Failed to create directory: $dir"
            return 1
        }
    fi
}

# Get the source file for a library
get_library_source() {
    local lib="$1"
    echo "/build/preload-libs/${lib}.c"
}

# Check if a library source exists
library_exists() {
    local lib="$1"
    local source=$(get_library_source "$lib")
    [ -f "$source" ]
}

# Get output directory for an architecture
get_output_dir() {
    local arch="$1"
    local libc="${LIBC_TYPE:-glibc}"
    echo "/build/output-preload/$libc/$arch"
}

# Get log file path
get_log_file() {
    local lib="$1"
    local arch="$2"
    echo "/build/logs-preload/${lib}-${arch}-$(date +%Y%m%d-%H%M%S).log"
}


# Get toolchain prefix for an architecture
get_toolchain_prefix() {
    local arch="$1"
    
    case "$arch" in
        x86_64)      echo "x86_64-unknown-linux-gnu" ;;
        aarch64)     echo "aarch64-unknown-linux-gnu" ;;
        arm32v7le)   echo "arm-cortex_a7-linux-gnueabihf" ;;
        i486)        echo "i486-unknown-linux-gnu" ;;
        mips64le)    echo "mips64el-unknown-linux-gnu" ;;
        ppc64le)     echo "powerpc64le-unknown-linux-gnu" ;;
        riscv64)     echo "riscv64-unknown-linux-gnu" ;;
        s390x)       echo "s390x-unknown-linux-gnu" ;;
        aarch64be)   echo "aarch64be-unknown-linux-gnu" ;;
        mips64)      echo "mips64-unknown-linux-gnu" ;;
        armv5)       echo "armv5-unknown-linux-gnueabi" ;;
        armv6)       echo "armv6-unknown-linux-gnueabihf" ;;
        ppc32)       echo "powerpc-unknown-linux-gnu" ;;
        sparc64)     echo "sparc64-unknown-linux-gnu" ;;
        sh4)         echo "sh4-unknown-linux-gnu" ;;
        mips32)      echo "mips32-unknown-linux-gnu" ;;
        mips32el)    echo "mips32el-unknown-linux-gnu" ;;
        riscv32)     echo "riscv32-unknown-linux-gnu" ;;
        microblazeel) echo "microblazeel-unknown-linux-gnu" ;;
        microblazebe) echo "microblazebe-unknown-linux-gnu" ;;
        nios2)       echo "nios2-unknown-linux-gnu" ;;
        openrisc)    echo "openrisc-unknown-linux-gnu" ;;
        arcle)       echo "arcle-unknown-linux-gnu" ;;
        xtensa)      echo "xtensa-unknown-linux-gnu" ;;
        m68k)        echo "m68k-unknown-linux-gnu" ;;
        *)           echo "${arch}-unknown-linux-gnu" ;;
    esac
}