#!/bin/bash
# Common build flags helper functions

# Get appropriate compiler flags for an architecture
get_compile_flags() {
    local arch=$1
    local tool=$2
    local base_flags="-static -Os -ffunction-sections -fdata-sections"
    
    # Add architecture-specific flags
    if [ -n "${CFLAGS_ARCH:-}" ]; then
        base_flags="$base_flags $CFLAGS_ARCH"
    fi
    
    # Apply -fno-pie and -no-pie flags universally for all architectures
    # Skip both PIE flags for ARM hard-float architectures due to compiler incompatibility
    case "$arch" in
        arm32v5lehf|arm32v7le|arm32v7lehf|armv6|armv7r)
            # ARM hard-float architectures can't handle PIE flags with their specific flags
            ;;
        sh2|sh2eb|sh4|sh4eb|microblaze|microblazeel|or1k|mipsn32|mipsn32el)
            # These architectures need PIE flags to avoid linker issues (original NO_PIE_ARCHS)
            base_flags="$base_flags -fno-pie -no-pie"
            ;;
        *)
            base_flags="$base_flags -fno-pie -no-pie"
            ;;
    esac
    
    # Add reproducible build seed
    base_flags="$base_flags -frandom-seed=${tool}-${arch}"
    
    echo "$base_flags"
}

# Get appropriate linker flags for an architecture
get_link_flags() {
    local arch=$1
    local base_flags="-static -Wl,--gc-sections"
    
    # Apply -no-pie and --build-id=sha1 flags universally for all architectures
    # Skip -no-pie for ARM hard-float architectures due to compiler incompatibility
    case "$arch" in
        arm32v5lehf|arm32v7le|arm32v7lehf|armv6|armv7r)
            # ARM hard-float architectures can't handle -no-pie with their specific flags
            base_flags="$base_flags -Wl,--build-id=sha1"
            ;;
        *)
            base_flags="$base_flags -no-pie -Wl,--build-id=sha1"
            ;;
    esac
    
    echo "$base_flags"
}

# Export functions
export -f get_compile_flags
export -f get_link_flags