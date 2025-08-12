#!/bin/bash
set -euo pipefail

# Tool information
TOOL_NAME="ply"
TOOL_VERSION="2.4.0"

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/build_helpers.sh"
source "${SCRIPT_DIR}/../lib/build_flags.sh"

# Set up directories
SOURCES_DIR="${SOURCES_DIR:-/build/sources}"
OUTPUT_DIR="${OUTPUT_DIR:-/build/output}"

get_source_url() {
    echo "https://github.com/wkz/ply/releases/download/${TOOL_VERSION}/ply-${TOOL_VERSION}.tar.gz"
}

get_version() {
    echo "${TOOL_VERSION}"
}

build_ply() {
    local arch="$1"
    
    # Set up architecture environment
    setup_arch "$arch" || {
        log_tool_error "$TOOL_NAME" "Failed to setup architecture: $arch"
        return 1
    }
    
    local build_name="${TOOL_NAME}-${TOOL_VERSION}-${arch}"
    local build_dir="/tmp/build"
    local arch_build_dir="${build_dir}/${build_name}"
    
    log_tool "Building ${TOOL_NAME} ${TOOL_VERSION} for ${arch}..."
    
    # Set up build directory
    rm -rf "$arch_build_dir"
    mkdir -p "$arch_build_dir"
    
    # Set up error handling
    trap "cleanup_build_dir '$arch_build_dir'" EXIT
    
    # Download source
    download_source "$arch" || return 1
    
    # Build
    if ! build_tool "$arch" "$arch_build_dir"; then
        log_tool_error "$TOOL_NAME" "Build failed for $arch"
        return 1
    fi
    
    # Install
    if ! install_tool "$arch" "$arch_build_dir" "/build/output/$arch"; then
        log_tool_error "$TOOL_NAME" "Installation failed for $arch"
        return 1
    fi
    
    trap - EXIT
    cleanup_build_dir "$arch_build_dir"
    
    return 0
}

download_source() {
    local arch="$1"
    local url=$(get_source_url)
    local filename="${TOOL_NAME}-${TOOL_VERSION}.tar.gz"
    
    # Download if not already present
    if [ ! -f "${SOURCES_DIR}/${filename}" ]; then
        log_tool "$(date +%H:%M:%S)" "Downloading ${TOOL_NAME} source..."
        wget -q -O "${SOURCES_DIR}/${filename}" "$url" || {
            log_tool "$(date +%H:%M:%S)" "ERROR: Failed to download source" >&2
            return 1
        }
    fi
    
    return 0
}

build_tool() {
    local arch="$1"
    local build_dir="$2"
    
    cd "${build_dir}"
    
    # Install bsd-compat-headers if not present (temporary fix)
    if [ ! -f /usr/include/sys/queue.h ]; then
        log_tool "$(date +%H:%M:%S)" "Installing bsd-compat-headers..."
        apk add --no-cache bsd-compat-headers >/dev/null 2>&1 || true
    fi
    
    # Extract source
    log_tool "$(date +%H:%M:%S)" "Extracting ${TOOL_NAME} source..."
    tar xzf "${SOURCES_DIR}/${TOOL_NAME}-${TOOL_VERSION}.tar.gz" || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Failed to extract source" >&2
        return 1
    }
    
    cd "${TOOL_NAME}-${TOOL_VERSION}"
    
    # Generate configure script
    log_tool "$(date +%H:%M:%S)" "Running autogen.sh..."
    # Run in a clean environment to avoid git warnings
    env -i PATH="/usr/bin:/bin" ./autogen.sh || {
        log_tool "$(date +%H:%M:%S)" "ERROR: autogen.sh failed" >&2
        return 1
    }
    
    # Configure
    log_tool "$(date +%H:%M:%S)" "Configuring ${TOOL_NAME} for ${arch}..."
    
    # Set up cross-compilation environment
    local host_triplet=""
    case "$arch" in
        x86_64)      host_triplet="x86_64-linux-musl" ;;
        i486)        host_triplet="i486-linux-musl" ;;
        ix86le)      host_triplet="i686-linux-musl" ;;
        aarch64)     host_triplet="aarch64-linux-musl" ;;
        aarch64_be)  host_triplet="aarch64_be-linux-musl" ;;
        arm32v5le)   host_triplet="arm-linux-musleabi" ;;
        arm32v5lehf) host_triplet="arm-linux-musleabihf" ;;
        arm32v7le)   host_triplet="armv7-linux-musleabi" ;;
        arm32v7lehf) host_triplet="armv7-linux-musleabihf" ;;
        armeb)       host_triplet="armeb-linux-musleabi" ;;
        armv6)       host_triplet="armv6-linux-musleabi" ;;
        armv7m)      host_triplet="armv7m-linux-musleabi" ;;
        armv7r)      host_triplet="armv7r-linux-musleabi" ;;
        mips32v2le)  host_triplet="mipsel-linux-musl" ;;
        mips32v2be)  host_triplet="mips-linux-musl" ;;
        mips64)      host_triplet="mips64-linux-musl" ;;
        mips64le)    host_triplet="mips64el-linux-musl" ;;
        ppc32be)     host_triplet="powerpc-linux-musl" ;;
        powerpcle)   host_triplet="powerpcle-linux-musl" ;;
        powerpc64)   host_triplet="powerpc64-linux-musl" ;;
        ppc64le)     host_triplet="powerpc64le-linux-musl" ;;
        riscv32)     host_triplet="riscv32-linux-musl" ;;
        riscv64)     host_triplet="riscv64-linux-musl" ;;
        *)
            log_tool "$(date +%H:%M:%S)" "WARNING: Unknown architecture ${arch}, using generic host"
            host_triplet="${arch}-linux-musl"
            ;;
    esac
    
    # Get proper flags from centralized configuration
    local cflags=$(get_compile_flags "$arch" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch")
    
    # Configure with static linking
    # Include system headers for BSD compatibility
    CFLAGS="$cflags -I/usr/include" \
    LDFLAGS="$ldflags" \
    ./configure \
        --host="${host_triplet}" \
        --prefix=/usr \
        --enable-static \
        --disable-shared \
        || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Configure failed" >&2
        return 1
    }
    
    # Build
    log_tool "$(date +%H:%M:%S)" "Building ${TOOL_NAME}..."
    make -j$(nproc) LDFLAGS="$ldflags" AM_LDFLAGS="-all-static" || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Build failed" >&2
        return 1
    }
    
    return 0
}

install_tool() {
    local arch="$1" 
    local build_dir="$2"
    local install_dir="$3"
    
    cd "${build_dir}/${TOOL_NAME}-${TOOL_VERSION}"
    
    log_tool "$(date +%H:%M:%S)" "Installing ${TOOL_NAME} to ${install_dir}..."
    
    # Find and install the binary
    local ply_binary=""
    if [ -f "src/ply/ply" ]; then
        ply_binary="src/ply/ply"
    elif [ -f "src/.libs/ply" ]; then
        ply_binary="src/.libs/ply"
    elif [ -f "ply" ]; then
        ply_binary="ply"
    else
        # Search for the binary
        ply_binary=$(find . -name "ply" -type f -executable | grep -v "\.sh$" | head -1)
    fi
    
    if [ -z "$ply_binary" ] || [ ! -f "$ply_binary" ]; then
        log_tool "$(date +%H:%M:%S)" "ERROR: Could not find ply binary" >&2
        find . -name "ply*" -type f | head -20
        return 1
    fi
    
    install -D -m 755 "$ply_binary" "${install_dir}/ply" || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Failed to install ply binary from $ply_binary" >&2
        return 1
    }
    
    # Verify it's statically linked
    if ! file "${install_dir}/ply" | grep -qE "(statically linked|static-pie linked)"; then
        log_tool "$(date +%H:%M:%S)" "ERROR: Binary is not statically linked!" >&2
        ldd "${install_dir}/ply" || true
        return 1
    fi
    
    # Strip the binary
    log_tool "$(date +%H:%M:%S)" "Stripping ${TOOL_NAME} binary..."
    "${STRIP}" "${install_dir}/ply" || {
        log_tool "$(date +%H:%M:%S)" "WARNING: Failed to strip binary" >&2
    }
    
    # Show final size
    local final_size=$(ls -lh "${install_dir}/ply" | awk '{print $5}')
    log_tool "$(date +%H:%M:%S)" "Final binary size: $final_size"
    
    return 0
}

main() {
    validate_args 1 "Usage: $0 <architecture>\nBuild ply for specified architecture" "$@"
    
    local arch=$1
    
    # Check if architecture is supported by ply
    # Based on actual implementation and known working architectures
    case "$arch" in
        x86_64)
            # x86_64.c - little endian only
            ;;
        aarch64)
            # aarch64.c - little endian only (aarch64_be not supported per GitHub issue #36)
            ;;
        arm32v5le|arm32v5lehf|arm32v7le|arm32v7lehf|armv6)
            # arm.c - little endian ARM 32-bit variants
            ;;
        mips32v2le|mips64le)
            # mips.c - little endian MIPS variants (safer to assume LE only)
            ;;
        riscv32)
            # riscv32.c - little endian
            ;;
        riscv64)
            # riscv64.c - little endian
            ;;
        ppc64le)
            # powerpc.c - little endian PowerPC 64
            ;;
        *)
            log_tool "$(date +%H:%M:%S)" "ERROR: Architecture $arch is not supported by ply" >&2
            log_tool "$(date +%H:%M:%S)" "Supported: x86_64, aarch64 (LE), arm32 (LE), mips (LE), riscv32/64, ppc64le" >&2
            log_tool "$(date +%H:%M:%S)" "Note: Big-endian variants are not confirmed to work" >&2
            return 1
            ;;
    esac
    
    mkdir -p "/build/output/$arch"
    
    build_ply "$arch"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi