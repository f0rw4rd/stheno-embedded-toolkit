#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

standard_configure() {
    local arch=$1
    local tool_name=$2
    shift 2
    local extra_args=("$@")
    
    local common_args=(
        "--host=$HOST"
        "--enable-static"
        "--disable-shared"
        "--disable-nls"
        "--disable-dependency-tracking"
        "--without-x"
        "--disable-werror"
    )
    
    log_tool "$tool_name" "Configuring for $arch"
    ./configure "${common_args[@]}" "${extra_args[@]}"
}

create_build_dir() {
    local tool_name=$1
    local arch=$2
    local build_dir="/tmp/${tool_name}-build-${arch}-$$"
    
    mkdir -p "$build_dir"
    echo "$build_dir"
}

cleanup_build_dir() {
    local build_dir=$1
    local preserve_on_error=${2:-false}
    
    if [ -d "$build_dir" ]; then
        if [ "$preserve_on_error" = "true" ] && [ $? -ne 0 ]; then
            log_warn "Build failed, preserving build directory: $build_dir"
        else
            cd /
            rm -rf "$build_dir"
        fi
    fi
}

install_binary() {
    local source_file=$1
    local arch=$2
    local dest_name=$3
    local tool_name=$4
    
    if [ ! -f "$source_file" ]; then
        log_tool_error "$tool_name" "Binary not found: $source_file"
        return 1
    fi
    
    $STRIP "$source_file" || {
        log_tool_error "$tool_name" "Failed to strip binary for $arch"
        return 1
    }
    
    mkdir -p "/build/output/$arch"
    
    cp "$source_file" "/build/output/$arch/$dest_name" || {
        log_tool_error "$tool_name" "Failed to copy binary for $arch"
        return 1
    }
    
    # Report size
    local size=$(ls -lh "/build/output/$arch/$dest_name" | awk '{print $5}')
    log_tool "$tool_name" "Built successfully for $arch ($size)"
    
    return 0
}

verify_static_binary() {
    local binary_path=$1
    local tool_name=$2
    
    if command -v ldd >/dev/null 2>&1; then
        if ldd "$binary_path" 2>&1 | grep -q "not a dynamic executable"; then
            log_tool "$tool_name" "Binary is statically linked"
            return 0
        elif ldd "$binary_path" 2>&1 | grep -q "statically linked"; then
            log_tool "$tool_name" "Binary is statically linked"
            return 0
        else
            log_tool_error "$tool_name" "Binary appears to be dynamically linked!"
            ldd "$binary_path" 2>&1 | head -5
            return 1
        fi
    fi
    return 0
}

build_with_dependency() {
    local arch=$1
    local dep_name=$2
    local dep_builder_func=$3
    local tool_name=$4
    
    log_tool "$tool_name" "Building with $dep_name dependency for $arch"
    
    local dep_dir
    dep_dir=$($dep_builder_func "$arch") || {
        log_tool_error "$tool_name" "Failed to build/get $dep_name for $arch"
        return 1
    }
    
    echo "$dep_dir"
}

create_cross_cache() {
    local arch=$1
    local cache_file=$2
    
    cat > "$cache_file" << EOF
# Cross-compilation cache for $arch
ac_cv_func_malloc_0_nonnull=yes
ac_cv_func_realloc_0_nonnull=yes
ac_cv_func_mmap_fixed_mapped=yes
ac_cv_func_getaddrinfo=yes
ac_cv_working_alloca_h=yes
ac_cv_func_alloca_works=yes
ac_cv_c_bigendian=$([ "${arch#*be}" != "$arch" ] && echo "yes" || echo "no")
ac_cv_c_littleendian=$([ "${arch#*be}" = "$arch" ] && echo "yes" || echo "no")
ac_cv_func_setpgrp_void=yes
ac_cv_func_setgrent_void=yes
ac_cv_func_getpgrp_void=yes
ac_cv_func_getgrent_void=yes
ac_cv_sizeof_int=4
ac_cv_sizeof_long=$([ "${arch#*64}" != "$arch" ] && echo "8" || echo "4")
ac_cv_sizeof_long_long=8
ac_cv_sizeof_void_p=$([ "${arch#*64}" != "$arch" ] && echo "8" || echo "4")
ac_cv_sizeof_size_t=$([ "${arch#*64}" != "$arch" ] && echo "8" || echo "4")
ac_cv_sizeof_pid_t=4
ac_cv_sizeof_uid_t=4
ac_cv_sizeof_gid_t=4
EOF
}

build_tool_generic() {
    local tool_name=$1
    local arch=$2
    local configure_func=$3
    local build_func=$4
    local install_func=$5
    
    # Check if binary already exists
    if check_binary_exists "$arch" "$tool_name"; then
        return 0
    fi
    
    # Setup architecture
    if ! setup_arch "$arch"; then
        log_tool_error "$tool_name" "Unknown architecture: $arch"
        return 1
    fi
    
    # Ensure toolchain exists
    if ! download_toolchain "$arch"; then
        return 1
    fi
    
    # Create build directory
    local build_dir
    build_dir=$(create_build_dir "$tool_name" "$arch")
    cd "$build_dir" || return 1
    
    # Set up error handling to cleanup on failure
    trap "cleanup_build_dir '$build_dir'" EXIT
    
    # Download source if needed
    if ! download_source; then
        log_tool_error "$tool_name" "Failed to download source"
        return 1
    fi
    
    # Get build flags
    local cflags=$(get_compile_flags "$arch" "$tool_name")
    local ldflags=$(get_link_flags "$arch")
    export CFLAGS="$cflags"
    export LDFLAGS="$ldflags"
    export CC="${CROSS_COMPILE}gcc"
    export CXX="${CROSS_COMPILE}g++"
    export AR="${CROSS_COMPILE}ar"
    export RANLIB="${CROSS_COMPILE}ranlib"
    export STRIP="${CROSS_COMPILE}strip"
    export NM="${CROSS_COMPILE}nm"
    
    # Configure
    if ! $configure_func "$arch"; then
        log_tool_error "$tool_name" "Configuration failed for $arch"
        return 1
    fi
    
    # Build
    if ! $build_func "$arch"; then
        log_tool_error "$tool_name" "Build failed for $arch"
        return 1
    fi
    
    # Install
    if ! $install_func "$arch"; then
        log_tool_error "$tool_name" "Installation failed for $arch"
        return 1
    fi
    
    # Remove trap and cleanup
    trap - EXIT
    cleanup_build_dir "$build_dir"
    
    return 0
}