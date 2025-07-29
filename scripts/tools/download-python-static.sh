#!/bin/bash
# Download static Python builds from python-build-standalone project
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# Python-build-standalone release info
PYTHON_VERSION="${PYTHON_VERSION:-3.12.7}"
PYTHON_BUILD_DATE="${PYTHON_BUILD_DATE:-20241016}"
GITHUB_REPO="astral-sh/python-build-standalone"
BASE_URL="https://github.com/${GITHUB_REPO}/releases/download/${PYTHON_BUILD_DATE}"

# Architecture mappings
declare -A PYTHON_ARCH_MAP=(
    # x86_64
    ["x86_64"]="x86_64-unknown-linux-gnu"
    ["amd64"]="x86_64-unknown-linux-gnu"
    
    # ARM 64-bit
    ["aarch64"]="aarch64-unknown-linux-gnu"
    ["arm64"]="aarch64-unknown-linux-gnu"
    
    # x86 32-bit
    ["i686"]="i686-unknown-linux-gnu"
    ["i386"]="i686-unknown-linux-gnu"
    ["i486"]="i686-unknown-linux-gnu"
    ["i586"]="i686-unknown-linux-gnu"
    
    # ARM 32-bit (limited support)
    ["armv7l"]="armv7-unknown-linux-gnueabihf"
    ["armv7"]="armv7-unknown-linux-gnueabihf"
)

# Download and extract Python for a specific architecture
download_python_static() {
    local arch=$1
    local output_dir="${2:-/build/output/$arch}"
    
    echo "[python-static] Downloading static Python for $arch..."
    
    # Map architecture
    local python_arch="${PYTHON_ARCH_MAP[$arch]}"
    if [ -z "$python_arch" ]; then
        echo "[python-static] Architecture $arch not supported by python-build-standalone"
        echo "[python-static] Supported architectures: ${!PYTHON_ARCH_MAP[@]}"
        return 1
    fi
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Check if already downloaded
    if [ -f "$output_dir/python3" ] && [ -d "$output_dir/python" ]; then
        echo "[python-static] Python already downloaded for $arch"
        return 0
    fi
    
    # Construct filename - python-build-standalone uses specific naming
    local filename="cpython-${PYTHON_VERSION}+${PYTHON_BUILD_DATE}-${python_arch}-install_only.tar.gz"
    local url="${BASE_URL}/${filename}"
    local temp_dir="/tmp/python-static-${arch}-$$"
    
    echo "[python-static] Downloading from: $url"
    
    # Create temp directory
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    # Download the archive
    if ! wget -q --show-progress "$url" -O "$filename"; then
        echo "[python-static] Failed to download Python for $arch"
        echo "[python-static] URL: $url"
        cd /
        rm -rf "$temp_dir"
        return 1
    fi
    
    echo "[python-static] Extracting Python..."
    
    # Extract the archive
    if ! tar xzf "$filename"; then
        echo "[python-static] Failed to extract Python archive"
        cd /
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Find the python directory (usually 'python')
    local python_dir=$(find . -maxdepth 1 -type d -name "python*" | head -1)
    if [ -z "$python_dir" ]; then
        python_dir="python"
    fi
    
    if [ ! -d "$python_dir" ]; then
        echo "[python-static] Python directory not found after extraction"
        cd /
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Move Python installation to output directory
    echo "[python-static] Installing Python to $output_dir..."
    
    # Copy the entire Python directory
    cp -r "$python_dir" "$output_dir/python" || {
        echo "[python-static] Failed to copy Python directory"
        cd /
        rm -rf "$temp_dir"
        return 1
    }
    
    # Create symlink for python3 binary in the arch directory
    if [ -f "$output_dir/python/bin/python3" ]; then
        ln -sf python/bin/python3 "$output_dir/python3"
        echo "[python-static] Created python3 symlink"
    else
        echo "[python-static] Warning: python3 binary not found in expected location"
    fi
    
    # Also create a standalone python3 binary by copying (for compatibility)
    if [ -f "$output_dir/python/bin/python3" ]; then
        cp "$output_dir/python/bin/python3" "$output_dir/python3-static"
        echo "[python-static] Created standalone python3-static binary"
    fi
    
    # Clean up
    cd /
    rm -rf "$temp_dir"
    
    # Show what was installed
    echo "[python-static] Python installation completed for $arch"
    echo "[python-static] Installed files:"
    echo "  - $output_dir/python/ (full Python installation)"
    echo "  - $output_dir/python3 (symlink to python/bin/python3)"
    echo "  - $output_dir/python3-static (standalone copy)"
    
    # Test the installation
    if [ -x "$output_dir/python/bin/python3" ]; then
        echo "[python-static] Testing Python installation..."
        "$output_dir/python/bin/python3" --version || {
            echo "[python-static] Warning: Python test failed"
        }
    fi
    
    return 0
}

# List available Python versions
list_available_versions() {
    echo "[python-static] Checking available Python versions..."
    echo "[python-static] Note: This queries GitHub API and may be rate-limited"
    
    # Get releases from GitHub API
    local releases_url="https://api.github.com/repos/${GITHUB_REPO}/releases"
    
    if command -v curl >/dev/null 2>&1; then
        curl -s "$releases_url" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4 | head -20
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$releases_url" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4 | head -20
    else
        echo "[python-static] Neither curl nor wget available"
        return 1
    fi
}

# Main function
main() {
    local action="${1:-download}"
    local arch="${2:-}"
    
    case "$action" in
        download)
            if [ -z "$arch" ]; then
                echo "Usage: $0 download <architecture>"
                echo "Supported architectures: ${!PYTHON_ARCH_MAP[@]}"
                exit 1
            fi
            download_python_static "$arch"
            ;;
        list)
            list_available_versions
            ;;
        *)
            echo "Usage: $0 {download|list} [architecture]"
            echo ""
            echo "Actions:"
            echo "  download <arch>  - Download Python for specified architecture"
            echo "  list            - List available Python versions"
            echo ""
            echo "Supported architectures: ${!PYTHON_ARCH_MAP[@]}"
            echo ""
            echo "Environment variables:"
            echo "  PYTHON_VERSION      - Python version (default: 3.12.7)"
            echo "  PYTHON_BUILD_DATE   - Build date tag (default: 20241016)"
            exit 1
            ;;
    esac
}

main "$@"