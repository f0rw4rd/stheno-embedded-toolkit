#!/bin/bash
# Unified build system for glibc static tools
set -e

# Base directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load common functions
source "$SCRIPT_DIR/lib/common.sh"

# Override paths for glibc builds
TOOLCHAINS_DIR="/build/toolchains-glibc-static"
OUTPUT_DIR="/build/output-glibc-static"
BUILD_DIR="/build/build-glibc-static"
SOURCES_DIR="/build/sources"
DEPS_PREFIX="/build/deps"
LOGS_DIR="/build/logs-glibc-static"

# Create directories
mkdir -p "$BUILD_DIR" "$SOURCES_DIR" "$DEPS_PREFIX" "$LOGS_DIR"

# Parse arguments
TOOL="${1:-all}"
ARCH="${2:-all}"
DEBUG="${DEBUG:-}"

# Get list of supported tools
get_glibc_tools() {
    echo "ltrace"  # Currently only ltrace
}

# Setup architecture with glibc toolchain
setup_arch_glibc() {
    local arch="$1"
    
    # Map architecture to toolchain prefix
    case "$arch" in
        x86_64)      TOOLCHAIN_PREFIX="x86_64" ;;
        aarch64)     TOOLCHAIN_PREFIX="aarch64" ;;
        arm32v7le)   TOOLCHAIN_PREFIX="armv7-eabihf" ;;
        i486)        TOOLCHAIN_PREFIX="x86-i686" ;;
        mips64le)    TOOLCHAIN_PREFIX="mips64el-n32" ;;
        ppc64le)     TOOLCHAIN_PREFIX="powerpc64le-power8" ;;
        riscv64)     TOOLCHAIN_PREFIX="riscv64-lp64d" ;;
        s390x)       TOOLCHAIN_PREFIX="s390x-z13" ;;
        *) 
            log_error "Unsupported architecture for glibc: $arch"
            return 1
            ;;
    esac
    
    # Check if toolchain exists
    local toolchain_dir="${TOOLCHAINS_DIR}/${TOOLCHAIN_PREFIX}--glibc--stable-2024.02-1"
    if [ ! -d "$toolchain_dir" ]; then
        log_error "Toolchain not found for $arch at $toolchain_dir"
        return 1
    fi
    
    # Set up environment
    export PATH="${toolchain_dir}/bin:$PATH"
    export CC="${TOOLCHAIN_PREFIX}--glibc--stable-2024.02-1-gcc"
    export CXX="${TOOLCHAIN_PREFIX}--glibc--stable-2024.02-1-g++"
    export AR="${TOOLCHAIN_PREFIX}--glibc--stable-2024.02-1-ar"
    export STRIP="${TOOLCHAIN_PREFIX}--glibc--stable-2024.02-1-strip"
    export TOOLCHAIN_PREFIX
    
    # Export for build scripts
    export SCRIPT_DIR TOOLCHAINS_DIR OUTPUT_DIR BUILD_DIR SOURCES_DIR DEPS_PREFIX LOGS_DIR
}

# Build a single tool
build_glibc_tool() {
    local tool="$1"
    local arch="$2"
    
    log "Building $tool for $arch with glibc..."
    
    # Create architecture output directory
    local arch_output="${OUTPUT_DIR}/${arch}"
    mkdir -p "$arch_output"
    
    # Set up architecture
    if ! setup_arch_glibc "$arch"; then
        return 1
    fi
    
    # Build the tool
    local build_script="${SCRIPT_DIR}/tools/build-${tool}.sh"
    if [ ! -f "$build_script" ]; then
        log_error "Build script not found: $build_script"
        return 1
    fi
    
    # Source the build script (it will use our exported variables)
    source "$build_script"
    
    # Run the build
    if main "$arch"; then
        log "Successfully built $tool for $arch"
        return 0
    else
        log_error "Failed to build $tool for $arch"
        return 1
    fi
}

# Main build logic
main() {
    log "==================================="
    log "Glibc Static Build System"
    log "==================================="
    log "Tool: $TOOL"
    log "Architecture: $ARCH"
    log "==================================="
    
    # Get list of tools to build
    if [ "$TOOL" = "all" ]; then
        TOOLS_TO_BUILD=$(get_glibc_tools)
    else
        TOOLS_TO_BUILD="$TOOL"
    fi
    
    # Get list of architectures
    if [ "$ARCH" = "all" ]; then
        # Limited architectures for glibc static builds
        ARCHS_TO_BUILD="x86_64 aarch64 arm32v7le i486"
    else
        ARCHS_TO_BUILD="$ARCH"
    fi
    
    # Build each tool for each architecture
    local total=0
    local success=0
    local failed=0
    
    for tool in $TOOLS_TO_BUILD; do
        for arch in $ARCHS_TO_BUILD; do
            total=$((total + 1))
            echo
            log "[$total] Building $tool for $arch..."
            
            if build_glibc_tool "$tool" "$arch"; then
                success=$((success + 1))
                log "[$total] ✓ Successfully built $tool for $arch"
            else
                failed=$((failed + 1))
                log_error "[$total] ✗ Failed to build $tool for $arch"
            fi
        done
    done
    
    echo
    log "==================================="
    log "Build Summary"
    log "==================================="
    log "Total: $total"
    log "Successful: $success"
    log "Failed: $failed"
    
    return $failed
}

# Run main
main