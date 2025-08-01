#!/bin/bash
# Build script for ltrace (glibc static build)
# Note: This is the first glibc-based static tool in the toolkit
set -e

source "${SCRIPT_DIR}/lib/common.sh"

TOOL_NAME="ltrace"
TOOL_VERSION="0.7.3-git"  # Using git version for latest fixes

# Tool-specific functions
download_source() {
    local arch="$1"
    
    if [ ! -f "sources/${TOOL_NAME}-${TOOL_VERSION}.tar.gz" ]; then
        log "Downloading ltrace source..."
        
        # Clone from git for latest version with fixes
        cd sources
        if [ ! -d "ltrace" ]; then
            git clone https://gitlab.com/cespedes/ltrace.git
        fi
        cd ltrace
        git fetch --all
        git checkout master
        git pull
        
        # Create tarball
        cd ..
        tar czf "${TOOL_NAME}-${TOOL_VERSION}.tar.gz" ltrace/
        cd ..
    fi
    
    # Extract
    log "Extracting ltrace source..."
    cd "$BUILD_DIR"
    tar xzf "$SOURCES_DIR/${TOOL_NAME}-${TOOL_VERSION}.tar.gz"
    mv ltrace "${TOOL_NAME}-${TOOL_VERSION}"
}

configure_build() {
    local arch="$1"
    local build_dir="$2"
    
    cd "$build_dir"
    
    # Run autogen if needed
    if [ ! -f "configure" ]; then
        log "Running autogen.sh..."
        ./autogen.sh
    fi
    
    # Get toolchain paths (using Bootlin naming convention)
    local toolchain_name="${TOOLCHAIN_PREFIX}--glibc--stable-2024.02-1"
    local toolchain_dir="/build/toolchains-glibc-static/${toolchain_name}"
    local sysroot="${toolchain_dir}/${TOOLCHAIN_PREFIX}/sysroot"
    
    # Build static dependencies first if needed
    build_static_deps "$arch"
    
    # Configure for static build
    # Note: We disable libunwind to simplify the build
    CFLAGS="-static -O2 -g -I${DEPS_PREFIX}/include -I${sysroot}/usr/include" \
    CXXFLAGS="-static -O2 -g -I${DEPS_PREFIX}/include -I${sysroot}/usr/include" \
    LDFLAGS="-static -L${DEPS_PREFIX}/lib -L${sysroot}/usr/lib" \
    CPPFLAGS="-I${DEPS_PREFIX}/include -I${sysroot}/usr/include" \
    ./configure \
        --host="${TOOLCHAIN_PREFIX}" \
        --prefix=/usr \
        --sysconfdir=/etc \
        --disable-shared \
        --enable-static \
        --disable-werror \
        --without-libunwind \
        --with-elfutils=no \
        --disable-selinux \
        CC="${toolchain_name}-gcc" \
        CXX="${toolchain_name}-g++" \
        AR="${toolchain_name}-ar" \
        STRIP="${toolchain_name}-strip" || {
        log_error "Configure failed"
        return 1
    }
}

build_static_deps() {
    local arch="$1"
    
    # Check if we already built deps
    if [ -f "${DEPS_PREFIX}/lib/libelf.a" ]; then
        log "Static dependencies already built"
        return 0
    fi
    
    log "Building static libelf..."
    
    # Download and build libelf
    cd "$BUILD_DIR"
    if [ ! -f "$SOURCES_DIR/elfutils-0.189.tar.bz2" ]; then
        wget -O "$SOURCES_DIR/elfutils-0.189.tar.bz2" \
            "https://sourceware.org/elfutils/ftp/0.189/elfutils-0.189.tar.bz2"
    fi
    
    tar xf "$SOURCES_DIR/elfutils-0.189.tar.bz2"
    cd elfutils-0.189
    
    # Configure elfutils for static build
    local toolchain_name="${TOOLCHAIN_PREFIX}--glibc--stable-2024.02-1"
    CFLAGS="-O2 -g" \
    ./configure \
        --host="${TOOLCHAIN_PREFIX}" \
        --prefix="${DEPS_PREFIX}" \
        --enable-static \
        --disable-shared \
        --disable-libdebuginfod \
        --disable-debuginfod \
        --without-bzlib \
        --without-lzma \
        CC="${toolchain_name}-gcc" \
        AR="${toolchain_name}-ar" || {
        log_error "elfutils configure failed"
        return 1
    }
    
    # Build only libelf
    make -C lib
    make -C libelf
    make -C libelf install
    
    cd "$BUILD_DIR"
    rm -rf elfutils-0.189
}

build_tool() {
    local arch="$1"
    local build_dir="$2"
    
    cd "$build_dir"
    
    # Build with explicit static flags
    make LDFLAGS="-static -L${DEPS_PREFIX}/lib" || {
        log_error "Build failed"
        return 1
    }
}

install_tool() {
    local arch="$1"
    local build_dir="$2"
    local install_dir="$3"
    
    cd "$build_dir"
    
    # Install the binary
    install -D -m 755 ltrace "$install_dir/ltrace"
    
    # Verify it's static
    if ! file "$install_dir/ltrace" | grep -q "statically linked"; then
        log_error "Binary is not statically linked!"
        return 1
    fi
    
    # Strip the binary
    local toolchain_name="${TOOLCHAIN_PREFIX}--glibc--stable-2024.02-1"
    "${toolchain_name}-strip" "$install_dir/ltrace" || true
}

# Main build
main "$@"