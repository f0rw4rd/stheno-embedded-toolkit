#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

GDB_VERSION="${GDB_VERSION:-v16.3-static}"
GITHUB_REPO="guyush1/gdb-static"
BASE_URL="https://github.com/${GITHUB_REPO}/releases/download/${GDB_VERSION}"

declare -A GDB_ARCH_MAP=(
    ["x86_64"]="x86_64"
    ["amd64"]="x86_64"
    
    ["aarch64"]="aarch64"
    ["arm64"]="aarch64"
    
    ["i686"]="i686"
    ["i386"]="i686"
    ["i486"]="i686"
    ["i586"]="i686"
    ["ix86le"]="i686"
    
    ["armv7l"]="arm"
    ["armv7"]="arm"
    ["arm32v7le"]="arm"
    ["arm32v7lehf"]="arm"
    
    ["powerpc"]="powerpc"
    ["ppc"]="powerpc"
    ["ppc32be"]="powerpc"
    ["powerpc64"]="powerpc64"
    ["ppc64"]="powerpc64"
    
    ["mips"]="mips"
    ["mips32v2be"]="mips"
    ["mipsel"]="mipsel"
    ["mips32v2le"]="mipsel"
    ["mips64"]="mips64"
    ["mips64el"]="mips64el"
    ["mips64le"]="mips64el"
    
    ["s390x"]="s390x"
)

download_gdb_variant() {
    local arch=$1
    local variant=$2  # "slim" or "full"
    local output_dir="${3:-/build/output/$arch}"
    local gdb_arch="${GDB_ARCH_MAP[$arch]}"
    
    if [ -z "$gdb_arch" ]; then
        log_tool "gdb-static" "Architecture $arch not supported by gdb-static project"
        
        case "$arch" in
            ppc64le|powerpc64le|powerpcle)
                log_tool "gdb-static" "Note: Only big-endian PowerPC (powerpc, powerpc64) is available, not little-endian variants"
                ;;
            arm32v5le|arm32v5lehf|armeb|armv6|armv7m|armv7r)
                log_tool "gdb-static" "Note: Only ARMv7 (arm) is available, not ARMv5, ARMv6, ARM big-endian, or specialized profiles"
                ;;
            mipsn32|mipsn32el|mips64n32|mips64n32el)
                log_tool "gdb-static" "Note: MIPS N32 ABI variants are not available"
                ;;
            sh2|sh2eb|sh4|sh4eb)
                log_tool "gdb-static" "Note: SuperH architectures are not supported"
                ;;
            microblaze|microblazeel)
                log_tool "gdb-static" "Note: Xilinx MicroBlaze architectures are not supported"
                ;;
            or1k)
                log_tool "gdb-static" "Note: OpenRISC architecture is not supported"
                ;;
            m68k)
                log_tool "gdb-static" "Note: Motorola 68000 architecture is not supported"
                ;;
        esac
        
        log_tool "gdb-static" "You will need to build GDB from source for this architecture"
        log_tool "gdb-static" "Supported architectures: aarch64, arm (armv7), i686, mips, mipsel, mips64, mips64el, powerpc, powerpc64, s390x, x86_64"
        return 1
    fi
    
    local variant_dir="$output_dir/gdb-$variant"
    mkdir -p "$variant_dir"
    
    if [ -f "$variant_dir/.download-complete" ]; then
        log_tool "gdb-static" "GDB $variant already downloaded for $arch"
        return 0
    fi
    
    local filename="gdb-static-${variant}-${gdb_arch}.tar.gz"
    local url="${BASE_URL}/${filename}"
    local temp_dir="/tmp/gdb-static-${variant}-${arch}-$$"
    
    log_tool "gdb-static" "Downloading $variant version from: $url"
    
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    if ! wget -q --show-progress "$url" -O "$filename"; then
        log_tool "gdb-static" "Failed to download GDB $variant for $arch"
        log_tool "gdb-static" "URL: $url"
        cd /
        rm -rf "$temp_dir"
        return 1
    fi
    
    log_tool "gdb-static" "Extracting GDB $variant..."
    
    if ! tar xzf "$filename"; then
        log_tool "gdb-static" "Failed to extract GDB archive"
        cd /
        rm -rf "$temp_dir"
        return 1
    fi
    
    log_tool "gdb-static" "Installing binaries to $variant_dir..."
    
    local installed_count=0
    for binary in *; do
        if [ -f "$binary" ] && [ -x "$binary" ]; then
            cp "$binary" "$variant_dir/" || {
                log_tool "gdb-static" "Failed to copy $binary"
                continue
            }
            chmod +x "$variant_dir/$binary"
            installed_count=$((installed_count + 1))
        fi
    done
    
    touch "$variant_dir/.download-complete"
    
    cd /
    rm -rf "$temp_dir"
    
    log_tool "gdb-static" "Installed $installed_count binaries for $variant variant"
    return 0
}

download_gdb_static() {
    local arch=$1
    local output_dir="${2:-/build/output/$arch}"
    local variant="${3:-both}"  # "slim", "full", or "both"
    
    log_tool "gdb-static" "Downloading static GDB for $arch (variant: $variant)..."
    
    mkdir -p "$output_dir"
    
    local success=0
    case "$variant" in
        slim)
            download_gdb_variant "$arch" "slim" "$output_dir" && success=1
            ;;
        full)
            download_gdb_variant "$arch" "full" "$output_dir" && success=1
            ;;
        both)
            download_gdb_variant "$arch" "slim" "$output_dir" && \
            download_gdb_variant "$arch" "full" "$output_dir" && success=1
            ;;
        *)
            log_tool "gdb-static" "Invalid variant: $variant (use slim, full, or both)"
            return 1
            ;;
    esac
    
    if [ $success -eq 1 ]; then
        if [ -f "$output_dir/gdb-full/gdb" ]; then
            ln -sf gdb-full/gdb "$output_dir/gdb"
        elif [ -f "$output_dir/gdb-slim/gdb" ]; then
            ln -sf gdb-slim/gdb "$output_dir/gdb"
        fi
        
        if [ -f "$output_dir/gdb-full/gdbserver" ]; then
            ln -sf gdb-full/gdbserver "$output_dir/gdbserver"
        elif [ -f "$output_dir/gdb-slim/gdbserver" ]; then
            ln -sf gdb-slim/gdbserver "$output_dir/gdbserver"
        fi
        
        log_tool "gdb-static" "Installation completed for $arch"
        log_tool "gdb-static" "Directory structure:"
        
        if [ -d "$output_dir/gdb-slim" ]; then
            echo "  - $output_dir/gdb-slim/ (minimal GDB)"
            local slim_count=$(ls -1 "$output_dir/gdb-slim" | grep -v "^\\." | wc -l)
            echo "    Contains $slim_count binaries"
        fi
        
        if [ -d "$output_dir/gdb-full" ]; then
            echo "  - $output_dir/gdb-full/ (GDB with all tools)"
            local full_count=$(ls -1 "$output_dir/gdb-full" | grep -v "^\\." | wc -l)
            echo "    Contains $full_count binaries including:"
            ls -1 "$output_dir/gdb-full" | grep -v "^\\." | head -10 | sed 's/^/      - /'
            if [ $full_count -gt 10 ]; then
                echo "      ... and $((full_count - 10)) more"
            fi
        fi
        
        echo "  - Symlinks in $output_dir/ for compatibility"
        
        log_tool "gdb-static" "Checking for and removing dynamically linked binaries..."
        local removed_count=0
        for dir in "$output_dir/gdb-slim" "$output_dir/gdb-full"; do
            if [ -d "$dir" ]; then
                for file in "$dir"/*; do
                    if [ -f "$file" ] && file "$file" 2>/dev/null | grep -qi "dynamically linked"; then
                        log_tool "gdb-static" "Removing dynamically linked binary: $file"
                        rm -f "$file"
                        ((removed_count++)) || true
                    fi
                done
            fi
        done
        
        if [ $removed_count -gt 0 ]; then
            log_tool "gdb-static" "Removed $removed_count dynamically linked binaries"
        else
            log_tool "gdb-static" "No dynamically linked binaries found"
        fi
    else
        log_tool "gdb-static" "Failed to download GDB variants"
        return 1
    fi
    
    return 0
}

cleanup_dynamic_binaries() {
    local arch="${1:-all}"
    log_tool "gdb-static" "Cleaning up dynamically linked GDB binaries..."
    
    local removed_count=0
    if [ "$arch" = "all" ]; then
        for arch_dir in /build/output/*/; do
            if [ -d "$arch_dir" ]; then
                for dir in "$arch_dir/gdb-slim" "$arch_dir/gdb-full"; do
                    if [ -d "$dir" ]; then
                        for file in "$dir"/*; do
                            if [ -f "$file" ] && file "$file" 2>/dev/null | grep -qi "dynamically linked"; then
                                log_tool "gdb-static" "Removing: $file"
                                rm -f "$file"
                                ((removed_count++)) || true
                            fi
                        done
                    fi
                done
            fi
        done
    else
        local output_dir="/build/output/$arch"
        for dir in "$output_dir/gdb-slim" "$output_dir/gdb-full"; do
            if [ -d "$dir" ]; then
                for file in "$dir"/*; do
                    if [ -f "$file" ] && file "$file" 2>/dev/null | grep -qi "dynamically linked"; then
                        log_tool "gdb-static" "Removing: $file"
                        rm -f "$file"
                        ((removed_count++)) || true
                    fi
                done
            fi
        done
    fi
    
    log_tool "gdb-static" "Removed $removed_count dynamically linked binaries"
}

list_available_versions() {
    log_tool "gdb-static" "Checking available GDB versions..."
    log_tool "gdb-static" "Note: This queries GitHub API and may be rate-limited"
    
    local releases_url="https://api.github.com/repos/${GITHUB_REPO}/releases"
    
    if command -v curl >/dev/null 2>&1; then
        curl -s "$releases_url" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4 | head -20
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$releases_url" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4 | head -20
    else
        log_tool "gdb-static" "Neither curl nor wget available"
        return 1
    fi
}

list_release_files() {
    local version="${1:-$GDB_VERSION}"
    log_tool "gdb-static" "Listing files in release $version..."
    
    local release_url="https://api.github.com/repos/${GITHUB_REPO}/releases/tags/${version}"
    
    if command -v curl >/dev/null 2>&1; then
        curl -s "$release_url" | grep -o '"name": "gdb-static-[^"]*"' | cut -d'"' -f4
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$release_url" | grep -o '"name": "gdb-static-[^"]*"' | cut -d'"' -f4
    else
        log_tool "gdb-static" "Neither curl nor wget available"
        return 1
    fi
}

main() {
    local action="${1:-download}"
    local arch="${2:-}"
    local variant="${3:-both}"
    
    case "$action" in
        download)
            if [ -z "$arch" ]; then
                echo "Usage: $0 download <architecture> [variant]"
                echo "Variants: slim, full, both (default: both)"
                echo "Supported architectures: aarch64 arm x86_64 i686 mips mipsel mips64 mips64el powerpc powerpc64 s390x"
                exit 1
            fi
            download_gdb_static "$arch" "/build/output/$arch" "$variant"
            ;;
        list)
            list_available_versions
            ;;
        list-files)
            list_release_files "${2:-$GDB_VERSION}"
            ;;
        cleanup)
            cleanup_dynamic_binaries "${2:-all}"
            ;;
        *)
            echo "Usage: $0 {download|list|list-files|cleanup} [architecture|version] [variant]"
            echo ""
            echo "Actions:"
            echo "  download <arch> [variant] - Download GDB for specified architecture"
            echo "                             Variants: slim, full, both (default: both)"
            echo "  list                     - List available GDB versions"
            echo "  cleanup [arch]           - Remove dynamically linked binaries (default: all)"
            echo "  list-files [ver]        - List files in a specific release"
            echo ""
            echo "Supported architectures: aarch64 arm x86_64 i686 mips mipsel mips64 mips64el powerpc powerpc64 s390x"
            echo ""
            echo "Environment variables:"
            echo "  GDB_VERSION - GDB version tag (default: v16.3-static)"
            exit 1
            ;;
    esac
}

main "$@"