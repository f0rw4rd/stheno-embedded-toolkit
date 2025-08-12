#!/bin/bash
# Build flags for glibc toolchain

# Get base compile flags for glibc builds
get_glibc_compile_flags() {
    local arch=$1
    local tool=$2
    
    # Base flags for all glibc builds
    local base_flags="-O2 -g"
    
    # Maximum compatibility flags
    base_flags="$base_flags -D_GNU_SOURCE -fno-strict-aliasing"
    
    # Disable PIE/PIC for maximum compatibility
    base_flags="$base_flags -fno-pic -fno-PIC -fno-pie -fno-PIE"
    
    # Add any existing CFLAGS
    if [ -n "${CFLAGS:-}" ]; then
        base_flags="$base_flags $CFLAGS"
    fi
    
    echo "$base_flags"
}

# Get base link flags for glibc builds
get_glibc_link_flags() {
    local arch=$1
    
    # Base flags for all glibc builds
    local base_flags="-Wl,--build-id=sha1"
    
    # Maximum compatibility: support both old and new hash styles
    base_flags="$base_flags -Wl,--hash-style=both"
    
    # Disable PIE for executables
    base_flags="$base_flags -no-pie"
    
    # Add static flag if needed
    if [ "${STATIC_BUILD:-true}" = "true" ]; then
        base_flags="-static $base_flags"
    fi
    
    # Add any existing LDFLAGS
    if [ -n "${LDFLAGS:-}" ]; then
        base_flags="$base_flags $LDFLAGS"
    fi
    
    echo "$base_flags"
}

# Get C++ flags for glibc builds
get_glibc_cxx_flags() {
    local arch=$1
    local tool=$2
    
    local base_flags=$(get_glibc_compile_flags "$arch" "$tool")
    
    # Add any existing CXXFLAGS
    if [ -n "${CXXFLAGS:-}" ]; then
        base_flags="$base_flags $CXXFLAGS"
    fi
    
    echo "$base_flags"
}

export -f get_glibc_compile_flags
export -f get_glibc_link_flags
export -f get_glibc_cxx_flags