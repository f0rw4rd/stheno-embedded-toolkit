#!/bin/bash
# Build shell utilities as static executables

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source required functions
source "$SCRIPT_DIR/../lib/common.sh"

# Version
get_version() {
    echo "1.0"
}

# Source URL (using local files)
get_source_url() {
    echo "local"
}

# Main build function
build_shell_static() {
    local arch="$1"
    log "Building shell static tools for $arch"
    
    # Setup architecture
    setup_arch "$arch"
    
    # Shell tools to build
    local tools="shell-bind shell-env shell-helper shell-reverse shell-fifo shell-loader"
    
    # Output directory
    local output_dir="/build/output/$arch/shell"
    mkdir -p "$output_dir"
    
    local build_dir="/tmp/build-shell-static-$arch-$$"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Build each tool
    local built=0
    for tool in $tools; do
        local source="/build/preload-libs/${tool}.c"
        local output="$output_dir/$tool"
        
        # Skip if already built
        if [ -f "$output" ] && [ "${SKIP_IF_EXISTS:-true}" = "true" ]; then
            log "Skipping $tool (already exists)"
            built=$((built + 1))
            continue
        fi
        
        if [ ! -f "$source" ]; then
            log_error "Source not found: $source"
            continue
        fi
        
        log "Building $tool..."
        
        # Compile with ENABLE_MAIN defined
        if ! $CC $CFLAGS -DENABLE_MAIN -c "$source" -o "${tool}.o" 2>&1; then
            log_error "Failed to compile $tool"
            continue
        fi
        
        # Link as static executable
        if ! $CC -static $LDFLAGS -o "$tool" "${tool}.o" 2>&1; then
            log_error "Failed to link $tool"
            continue
        fi
        
        # Strip
        $STRIP "$tool" 2>&1 || true
        
        # Copy to output
        cp "$tool" "$output"
        chmod +x "$output"
        
        # Show info
        local size=$(ls -lh "$output" 2>/dev/null | awk '{print $5}')
        log "Built: $output ($size)"
        
        built=$((built + 1))
    done
    
    # Cleanup
    cd /
    rm -rf "$build_dir"
    
    if [ $built -eq 0 ]; then
        log_error "No shell tools were built"
        return 1
    fi
    
    log "Successfully built $built shell tools"
    return 0
}

# Entry point
main() {
    local arch="$1"
    build_shell_static "$arch"
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi