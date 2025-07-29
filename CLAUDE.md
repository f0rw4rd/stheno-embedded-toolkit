# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

The Stheno Embedded Toolkit (formerly Medusa Embedded Toolkit) is a build system for creating static debugging tools for embedded systems. It builds statically-linked binaries for 32 different architectures using Docker and cross-compilation toolchains.

## Key Commands

### Building Tools

```bash
# Build all tools for all architectures (216+ binaries)
./build

# Build specific tool for all architectures
./build strace
./build busybox

# Build all tools for specific architecture
./build --arch arm32v5le
./build --arch x86_64

# Build specific tool for specific architecture
./build strace --arch arm32v5le

# Debug mode (verbose output)
./build -d strace --arch x86_64

# Clean output and logs
./build --clean
```

### Verifying Binaries

```bash
# Test built binaries using QEMU
./scripts/verify-binaries-qemu.sh
```

## Architecture

### Build Pipeline
1. **Docker Container**: Alpine Linux 3.18 build environment defined in `Dockerfile`
2. **Main Script**: `build` script orchestrates the build process
3. **Build Logic**: `scripts/build-unified.sh` manages the actual compilation
4. **Tool Scripts**: Individual build scripts in `scripts/tools/` for each tool
5. **Libraries**: Shared functions in `scripts/lib/` (common.sh, tools.sh, build_flags.sh, dependencies.sh)

### Directory Structure
- `output/`: Built binaries organized by architecture (e.g., `output/arm32v5le/strace`)
- `sources/`: Cached source code downloads
- `toolchains/`: Cross-compilation toolchains from musl.cc
- `logs/`: Build logs with timestamps
- `deps-cache/`: Dependency cache for faster rebuilds
- `configs/`: Architecture-specific configurations

### Cross-Compilation
The toolkit uses musl-cross-make toolchains for each architecture. Toolchains are downloaded on-demand and cached. All binaries are statically linked against musl libc for zero runtime dependencies.

### Supported Tools
- **strace**: System call tracer
- **busybox**: Multi-call binary with Unix utilities
- **bash**: Bourne Again Shell
- **socat/socat-ssl**: Socket relay tool
- **ncat/ncat-ssl**: Network utility
- **tcpdump**: Network packet analyzer
- **gdbserver**: Remote debugging server
- **gdb**: GNU debugger
- **nmap**: Network exploration tool

### Build Flags
All tools are built with:
- Static linking (`-static`)
- Size optimization (`-Os`)
- Link-time optimization where supported
- Strip symbols for smaller binaries
- Architecture-specific optimizations

## Development Notes

### Adding New Tools
1. Create build script in `scripts/tools/build-<toolname>.sh`
2. Add tool definition to `scripts/lib/tools.sh`
3. Follow existing patterns for download, configure, and build steps

### Debugging Build Issues
- Check logs in `logs/` directory (e.g., `logs/strace-arm32v5le-<timestamp>.log`)
- Use debug mode: `./build -d <tool> --arch <arch>`
- Build logs include full configure and make output

### Docker Volumes
The build system uses Docker volumes for caching:
- `stheno-sources`: Source code cache
- `stheno-toolchains`: Toolchain cache
- `stheno-deps-<arch>`: Architecture-specific dependency cache

These volumes persist between builds for efficiency.

## ARM Float ABI Compatibility Issues

Some ARM architectures may encounter float ABI mismatch errors during builds, particularly:
- **ARMv7-R** cores without FPU (using armv7r-linux-musleabihf toolchain)
- **ARMv5** architectures that lack FPU hardware

### Common Error
```
uses VFP register arguments, output does not
```

This occurs when hard-float toolchains (`-mfloat-abi=hard`) are used for architectures without FPU support.

### Solutions

1. **Check toolchain mappings** in `scripts/lib/common.sh`:
   - Soft-float toolchains end with `-musleabi`
   - Hard-float toolchains end with `-musleabihf`

2. **For affected architectures**, modify the toolchain URL:
   ```bash
   # Example: Change ARMv7-R to soft-float
   armv7r) url="https://musl.cc/arm-linux-musleabi-cross.tgz" ;;
   ```

3. **Update build flags** in `scripts/lib/build_flags.sh` for specific architectures:
   ```bash
   # Add soft-float flags for non-FPU architectures
   CFLAGS="$CFLAGS -mfloat-abi=soft -mfpu=none"
   ```

4. **Verify ABI compatibility** of built binaries:
   ```bash
   readelf -A output/<arch>/<tool> | grep "Tag_ABI_VFP_args"
   ```

### Architecture-Specific Notes
- **arm32v5le**: Uses soft-float by default (correct)
- **armv7r**: Uses hard-float toolchain with softfp ABI for compatibility
  - Set to `-mfpu=vfpv3-d16 -mfloat-abi=softfp` for maximum compatibility
  - The softfp ABI allows code to run on both FPU and non-FPU variants
- **armv7m**: Embedded profile, typically soft-float

When adding support for new architectures, carefully consider the float ABI requirements based on the target hardware capabilities.