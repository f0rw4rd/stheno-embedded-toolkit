#!/bin/bash
set -euo pipefail

# Tool information
TOOL_NAME="gdb"
TOOL_VERSION="14.1"

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/build_helpers.sh"
source "${SCRIPT_DIR}/../lib/build_flags.sh"

get_source_url() {
    echo "https://ftp.gnu.org/gnu/gdb/gdb-${TOOL_VERSION}.tar.xz"
}

get_version() {
    echo "${TOOL_VERSION}"
}

build_gdb() {
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
    local filename="gdb-${TOOL_VERSION}.tar.xz"
    
    # Download if not already present
    if [ ! -f "/build/sources/${filename}" ]; then
        log_tool "$(date +%H:%M:%S)" "Downloading ${TOOL_NAME} source..."
        wget -q -O "/build/sources/${filename}" "$url" || {
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
    
    # Extract source
    log_tool "$(date +%H:%M:%S)" "Extracting ${TOOL_NAME} source..."
    tar xf "/build/sources/gdb-${TOOL_VERSION}.tar.xz" || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Failed to extract source" >&2
        return 1
    }
    
    cd "gdb-${TOOL_VERSION}"
    
    # Configure for static build
    log_tool "$(date +%H:%M:%S)" "Configuring ${TOOL_NAME} for ${arch}..."
    
    # Configure for the target architecture
    local configure_args=""
    case "$arch" in
        x86_64) configure_args="--host=x86_64-linux-musl" ;;
        i486) configure_args="--host=i486-linux-musl" ;;
        ix86le) configure_args="--host=i686-linux-musl" ;;
        aarch64) configure_args="--host=aarch64-linux-musl" ;;
        arm32v5le) configure_args="--host=arm-linux-musleabi" ;;
        arm32v5lehf) configure_args="--host=arm-linux-musleabihf" ;;
        arm32v7le) configure_args="--host=armv7-linux-musleabi" ;;
        arm32v7lehf) configure_args="--host=armv7-linux-musleabihf" ;;
        mips32v2le) configure_args="--host=mipsel-linux-musl" ;;
        mips32v2be) configure_args="--host=mips-linux-musl" ;;
        ppc32be) configure_args="--host=powerpc-linux-musl" ;;
        ppc64le) configure_args="--host=powerpc64le-linux-musl" ;;
        *) configure_args="--host=${arch}-linux-musl" ;;
    esac
    
    # Get centralized flags
    local cflags=$(get_compile_flags "$arch" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch")
    local cxxflags=$(get_cxx_flags "$arch" "$TOOL_NAME")
    
    CFLAGS="$cflags" \
    CXXFLAGS="$cxxflags" \
    LDFLAGS="$ldflags" \
    ./configure \
        $configure_args \
        --target=${arch}-linux-musl \
        --prefix=/usr \
        --disable-shared \
        --enable-static \
        --disable-nls \
        --disable-werror \
        --disable-tui \
        --with-system-zlib \
        --with-static-standard-libraries \
        || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Configure failed" >&2
        return 1
    }
    
    # Build
    log_tool "$(date +%H:%M:%S)" "Building ${TOOL_NAME}..."
    make -j$(nproc) || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Build failed" >&2
        return 1
    }
    
    return 0
}

install_tool() {
    local arch="$1" 
    local build_dir="$2"
    local install_dir="$3"
    
    cd "${build_dir}/gdb-${TOOL_VERSION}"
    
    log_tool "$(date +%H:%M:%S)" "Installing ${TOOL_NAME} to ${install_dir}..."
    
    # Create both full and slim versions
    install -D -m 755 gdb/gdb "${install_dir}/gdb-full" || {
        log_tool "$(date +%H:%M:%S)" "ERROR: Failed to install gdb binary" >&2
        return 1
    }
    
    # Strip the full version
    "${STRIP}" "${install_dir}/gdb-full" || true
    
    # Create slim version (aggressively stripped)
    cp "${install_dir}/gdb-full" "${install_dir}/gdb-slim"
    "${STRIP}" --strip-all --remove-section=.comment --remove-section=.note "${install_dir}/gdb-slim" || true
    
    # Verify they're statically linked
    for variant in gdb-full gdb-slim; do
        if ! file "${install_dir}/${variant}" | grep -q "statically linked"; then
            log_tool "$(date +%H:%M:%S)" "ERROR: ${variant} is not statically linked!" >&2
            ldd "${install_dir}/${variant}" || true
            return 1
        fi
    done
    
    # Show final sizes
    local full_size=$(ls -lh "${install_dir}/gdb-full" | awk '{print $5}')
    local slim_size=$(ls -lh "${install_dir}/gdb-slim" | awk '{print $5}')
    log_tool "$(date +%H:%M:%S)" "Full binary size: $full_size"
    log_tool "$(date +%H:%M:%S)" "Slim binary size: $slim_size"
    
    return 0
}

main() {
    validate_args 1 "Usage: $0 <architecture>\nBuild gdb for specified architecture" "$@"
    
    local arch=$1
    
    mkdir -p "/build/output/$arch"
    
    build_gdb "$arch"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi