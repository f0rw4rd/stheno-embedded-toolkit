#!/bin/bash

# Unified architecture mapping
# Maps various architecture names to canonical musl names

map_arch_name() {
    local input_arch=$1
    
    case "$input_arch" in
        # Direct mappings (already canonical)
        arm32v5le|arm32v5lehf|arm32v7le|arm32v7lehf|armeb|armv6|armv7m|armv7r|\
        mips32v2le|mips32v2be|mipsn32|mipsn32el|mips64|mips64le|mips64n32|mips64n32el|\
        ppc32be|powerpcle|powerpc64|ppc64le|\
        i486|ix86le|x86_64|aarch64|aarch64_be|\
        sh2|sh2eb|sh4|sh4eb|\
        microblaze|microblazeel|or1k|m68k|s390x|\
        riscv32|riscv64)
            echo "$input_arch"
            ;;
            
        # Glibc/Bootlin names to musl names
        mips32)      echo "mips32v2be" ;;
        mips32el)    echo "mips32v2le" ;;
        armv5)       echo "arm32v5le" ;;
        ppc32)       echo "ppc32be" ;;
        openrisc)    echo "or1k" ;;
        aarch64be)   echo "aarch64_be" ;;
        
        # Common aliases
        arm)         echo "arm32v7le" ;;  # Default ARM
        mips)        echo "mips32v2be" ;; # Default MIPS
        ppc)         echo "ppc32be" ;;    # Default PowerPC
        
        *)
            echo "$input_arch"  # Return as-is if unknown
            ;;
    esac
}

# Reverse mapping for display purposes
get_display_arch_name() {
    local canonical_arch=$1
    
    case "$canonical_arch" in
        mips32v2be)  echo "mips32" ;;
        mips32v2le)  echo "mips32el" ;;
        arm32v5le)   echo "armv5" ;;
        ppc32be)     echo "ppc32" ;;
        or1k)        echo "openrisc" ;;
        aarch64_be)  echo "aarch64be" ;;
        *)           echo "$canonical_arch" ;;
    esac
}