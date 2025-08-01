#!/bin/bash
# Unified build system for glibc static tools
set -e

# Base directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load common functions - check both locations
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    source "$SCRIPT_DIR/lib/common.sh"
elif [ -f "$SCRIPT_DIR/preload/lib/common.sh" ]; then
    source "$SCRIPT_DIR/preload/lib/common.sh"
else
    # Define basic logging functions if common.sh not found
    log() { echo "[$(date +%H:%M:%S)] $*"; }
    log_error() { echo "[$(date +%H:%M:%S)] ERROR: $*" >&2; }
fi

# Override paths for glibc builds (reusing preload infrastructure)
TOOLCHAINS_DIR="/build/toolchains-preload"
OUTPUT_DIR="/build/output-glibc-static"
BUILD_DIR="/build/tmp/build-glibc-static"
SOURCES_DIR="/build/sources"
DEPS_PREFIX="/build/deps-glibc-static"
LOGS_DIR="/build/logs-glibc-static"

# Create directories at runtime
mkdir -p "$BUILD_DIR" "$SOURCES_DIR" "$DEPS_PREFIX" "$LOGS_DIR" "$OUTPUT_DIR"

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
            echo "[$(date +%H:%M:%S)] ERROR: Unsupported architecture for glibc: $arch" >&2
            return 1
            ;;
    esac
    
    # Map to actual toolchain names in the image
    case "$arch" in
        x86_64)      TOOLCHAIN_NAME="x86_64-unknown-linux-gnu" ;;
        aarch64)     TOOLCHAIN_NAME="aarch64-unknown-linux-gnu" ;;
        arm32v7le)   TOOLCHAIN_NAME="arm-cortex_a7-linux-gnueabihf" ;;
        i486)        TOOLCHAIN_NAME="i486-unknown-linux-gnu" ;;
        mips64le)    TOOLCHAIN_NAME="mips64el-unknown-linux-gnu" ;;
        ppc64le)     TOOLCHAIN_NAME="powerpc64le-unknown-linux-gnu" ;;
        riscv64)     TOOLCHAIN_NAME="riscv64-unknown-linux-gnu" ;;
        s390x)       TOOLCHAIN_NAME="s390x-unknown-linux-gnu" ;;
    esac
    
    # Check if toolchain exists
    local toolchain_dir="${TOOLCHAINS_DIR}/${TOOLCHAIN_NAME}"
    if [ ! -d "$toolchain_dir" ]; then
        echo "[$(date +%H:%M:%S)] ERROR: Toolchain not found for $arch at $toolchain_dir" >&2
        return 1
    fi
    
    # Set up environment
    export PATH="${toolchain_dir}/bin:$PATH"
    export CC="${TOOLCHAIN_NAME}-gcc"
    export CXX="${TOOLCHAIN_NAME}-g++"
    export AR="${TOOLCHAIN_NAME}-ar"
    export STRIP="${TOOLCHAIN_NAME}-strip"
    export TOOLCHAIN_PREFIX
    
    # Export for build scripts
    export SCRIPT_DIR TOOLCHAINS_DIR OUTPUT_DIR BUILD_DIR SOURCES_DIR DEPS_PREFIX LOGS_DIR
}

# Build a single tool
build_glibc_tool() {
    local tool="$1"
    local arch="$2"
    
    echo "[$(date +%H:%M:%S)] Building $tool for $arch with glibc..."
    
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
        echo "[$(date +%H:%M:%S)] ERROR: Build script not found: $build_script" >&2
        return 1
    fi
    
    # Source the build script (it will use our exported variables)
    source "$build_script"
    
    # Run the build
    if main "$arch"; then
        echo "[$(date +%H:%M:%S)] Successfully built $tool for $arch"
        return 0
    else
        echo "[$(date +%H:%M:%S)] ERROR: Failed to build $tool for $arch" >&2
        return 1
    fi
}

# Main build logic
main() {
    echo "==================================="
    echo "Glibc Static Build System"
    echo "==================================="
    echo "Tool: $TOOL"
    echo "Architecture: $ARCH"
    echo "==================================="
    
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
            echo "[$(date +%H:%M:%S)] [$total] Building $tool for $arch..."
            
            if build_glibc_tool "$tool" "$arch"; then
                success=$((success + 1))
                echo "[$(date +%H:%M:%S)] [$total] ✓ Successfully built $tool for $arch"
            else
                failed=$((failed + 1))
                echo "[$(date +%H:%M:%S)] [$total] ✗ Failed to build $tool for $arch" >&2
            fi
        done
    done
    
    echo
    echo "==================================="
    echo "Build Summary"
    echo "==================================="
    echo "Total: $total"
    echo "Successful: $success"
    echo "Failed: $failed"
    
    return $failed
}

# Run main
main