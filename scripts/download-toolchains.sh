#!/bin/bash
# Script to download all toolchains in parallel
set -e

TOOLCHAIN_DIR="/build/toolchains"
mkdir -p "$TOOLCHAIN_DIR"
cd "$TOOLCHAIN_DIR"

# Function to download and extract a toolchain
download_toolchain() {
    local url=$1
    local target_dir=$2
    local filename=$(basename "$url")
    
    echo "Downloading $target_dir..."
    if wget -q "$url" -O "$filename"; then
        tar xzf "$filename"
        local extracted_dir="${filename%.tgz}"
        extracted_dir="${extracted_dir%-cross}"
        if [ -d "$extracted_dir" ]; then
            mv "$extracted_dir" "$target_dir"
        fi
        rm -f "$filename"
        echo "✓ $target_dir"
    else
        echo "✗ Failed to download $target_dir"
        return 1
    fi
}

# Export function for parallel execution
export -f download_toolchain

# Define all toolchains
declare -a TOOLCHAINS=(
    "https://musl.cc/arm-linux-musleabi-cross.tgz arm32v5le"
    "https://musl.cc/arm-linux-musleabihf-cross.tgz arm32v5lehf"
    "https://musl.cc/armv7l-linux-musleabihf-cross.tgz arm32v7le"
    "https://musl.cc/armeb-linux-musleabi-cross.tgz armeb"
    "https://musl.cc/armv6-linux-musleabihf-cross.tgz armv6"
    "https://musl.cc/armv7m-linux-musleabi-cross.tgz armv7m"
    "https://musl.cc/armv7r-linux-musleabihf-cross.tgz armv7r"
    "https://musl.cc/aarch64-linux-musl-cross.tgz aarch64"
    "https://musl.cc/i686-linux-musl-cross.tgz ix86le"
    "https://musl.cc/x86_64-linux-musl-cross.tgz x86_64"
    "https://musl.cc/i486-linux-musl-cross.tgz i486"
    "https://musl.cc/mipsel-linux-musl-cross.tgz mips32v2le"
    "https://musl.cc/mips-linux-musl-cross.tgz mips32v2be"
    "https://musl.cc/mips-linux-musln32sf-cross.tgz mipsn32"
    "https://musl.cc/mipsel-linux-musln32sf-cross.tgz mipsn32el"
    "https://musl.cc/mips64el-linux-musl-cross.tgz mips64le"
    "https://musl.cc/mips64-linux-musln32-cross.tgz mips64n32"
    "https://musl.cc/mips64el-linux-musln32-cross.tgz mips64n32el"
    "https://musl.cc/powerpc-linux-musl-cross.tgz ppc32be"
    "https://musl.cc/powerpcle-linux-musl-cross.tgz powerpcle"
    "https://musl.cc/powerpc64-linux-musl-cross.tgz powerpc64"
    "https://musl.cc/powerpc64le-linux-musl-cross.tgz ppc64le"
    "https://musl.cc/sh2-linux-musl-cross.tgz sh2"
    "https://musl.cc/sh2eb-linux-musl-cross.tgz sh2eb"
    "https://musl.cc/sh4-linux-musl-cross.tgz sh4"
    "https://musl.cc/sh4eb-linux-musl-cross.tgz sh4eb"
    "https://musl.cc/microblaze-linux-musl-cross.tgz microblaze"
    "https://musl.cc/microblazeel-linux-musl-cross.tgz microblazeel"
    "https://musl.cc/or1k-linux-musl-cross.tgz or1k"
    "https://musl.cc/m68k-linux-musl-cross.tgz m68k"
    "https://musl.cc/s390x-linux-musl-cross.tgz s390x"
)

echo "Downloading ${#TOOLCHAINS[@]} toolchains in parallel..."

# Use GNU parallel if available, otherwise use xargs
if command -v parallel >/dev/null 2>&1; then
    printf '%s\n' "${TOOLCHAINS[@]}" | parallel -j 8 --colsep ' ' download_toolchain {1} {2}
else
    # Use xargs with -P for parallel processing
    printf '%s\n' "${TOOLCHAINS[@]}" | xargs -P 8 -I {} bash -c 'download_toolchain $@' _ {}
fi

# Special case: arm32v7lehf is a copy of arm32v7le
if [ -d "arm32v7le" ] && [ ! -d "arm32v7lehf" ]; then
    cp -a arm32v7le arm32v7lehf
    echo "✓ arm32v7lehf (copied from arm32v7le)"
fi

echo "All toolchains downloaded successfully"