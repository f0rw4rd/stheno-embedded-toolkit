# Stheno Embedded Toolkit Build System

Fast, reliable pipeline for building static debugging tools for embedded systems.

## About

This project is inspired by [CyberDanube's medusa-embedded-toolkit](https://github.com/CyberDanube/medusa-embedded-toolkit), which provides pre-compiled static binaries for embedded systems. While they focus on publishing the binaries, Stheno provides the complete build toolchain to create these binaries from source.

The name "Stheno" is a playful reference - in Greek mythology, Stheno was one of Medusa's sisters, both being Gorgons. This reflects our relationship: same family of tools, different approach.

## Quick Start

```bash
# Build all tools for all architectures
./build

# Build specific tool
./build strace

# Build for specific architecture
./build --arch arm32v5le

# Build specific tool for specific architecture
./build strace --arch arm32v5le
```

## Docker Build

The build system runs inside Docker automatically when you use the `./build` script. Docker is required for all builds.

## Build System Structure

```
.
├── build                       # Main build script
├── Dockerfile                 # Docker image for build environment
├── scripts/
│   ├── build-unified.sh       # Core build system
│   ├── lib/
│   │   ├── common.sh         # Shared functions
│   │   ├── tools.sh          # Tool-specific build functions
│   │   ├── build_flags.sh    # Build configuration
│   │   └── dependencies.sh   # Dependency management
│   └── tools/                 # Individual tool build scripts
├── output/                    # Built binaries (release directory)
└── configs/                   # Architecture configurations
```

## Available Tools

- **strace** - System call tracer
- **busybox** - Multi-call binary with Unix utilities  
- **bash** - Bourne Again Shell
- **socat** - Socket relay tool
- **ncat** - Network utility
- **tcpdump** - Network packet analyzer
- **gdbserver** - Remote debugging server
- **gdb** - GNU debugger
- **nmap** - Network exploration tool

## Supported Architectures

32 architectures are supported:

**ARM**: `aarch64`, `arm32v5le`, `arm32v5lehf`, `arm32v7le`, `arm32v7lehf`, `armeb`, `armv6`, `armv7m`

**x86**: `x86_64`, `i486`, `ix86le`

**MIPS**: `mips32v2be`, `mips32v2le`, `mips64le`, `mips64n32`, `mips64n32el`

**PowerPC**: `ppc32be`, `ppc64le`, `powerpc64`, `powerpcle`

**Other**: `m68k`, `microblaze`, `microblazeel`, `or1k`, `s390x`, `sh2`, `sh2eb`, `sh4`, `sh4eb`

## Build Options

```bash
./build [TOOL] [OPTIONS]

TOOL:
  all         Build all tools (default)
  strace      System call tracer
  busybox     Multi-call binary
  bash        Bourne Again Shell
  socat       Socket relay tool
  ncat        Network utility
  tcpdump     Network packet analyzer
  gdbserver   Remote debugging server
  gdb         GNU debugger

OPTIONS:
  --arch ARCH Build for specific architecture
  -j N        Use N parallel jobs (default: 4)
  --help      Show help message
```

## Requirements

- Docker
- 10GB+ free disk space
- Internet connection (for downloading sources/toolchains)

## Output

All compiled binaries are stored in the `output/` folder, which serves as the release directory:

- **Binaries**: `output/<architecture>/<tool>` (e.g., `output/arm32v7le/strace`)

The `output/` folder contains all the ready-to-use static binaries organized by architecture. Each subdirectory represents a target architecture and contains the tools compiled for that platform.

All binaries are statically linked with no runtime dependencies.

## Current Status

Successfully built **216 static binaries** across 32 architectures:
- **bash**: 29/32 architectures (90.6%)
- **busybox**: 28/32 architectures (87.5%)
- **strace**: 28/32 architectures (87.5%)
- **socat**: 28/32 architectures (87.5%)
- **socat-ssl**: 28/32 architectures (87.5%)
- **ncat**: 28/32 architectures (87.5%)
- **ncat-ssl**: 27/32 architectures (84.4%)
- **tcpdump**: 28/32 architectures (87.5%)
- **gdbserver**: 26/32 architectures (81.2%)
- **gdb**: 7/32 architectures (21.9%)
- **nmap**: 1/32 architectures (x86_64 only)

## Quick Status Check

```bash
# Count total binaries
find output -type f | wc -l

# Check by architecture
ls -la output/*/

# Check specific tool across architectures
ls -la output/*/strace
```

## Credits

This project builds upon the work of several excellent projects:

- **[musl-cross-make](https://github.com/richfelker/musl-cross-make)** - Provides the cross-compilation toolchains
- **[gdb-static](https://github.com/guyush1/gdb-static)** by guyush1 - Pre-built static GDB binaries for multiple architectures

### Tool Sources

All tools are built from their official upstream sources:
- BusyBox, Bash, strace, tcpdump, socat, nmap/ncat - Built from source
- GDB - Downloaded from gdb-static releases for reliability