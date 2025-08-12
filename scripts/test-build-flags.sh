#!/bin/bash
# Test script to verify build flags are correctly applied

set -e

echo "========================================"
echo "Build Flags Verification Test"
echo "========================================"
echo

# Function to check binary properties
check_binary() {
    local binary="$1"
    local arch="$2"
    
    if [ ! -f "$binary" ]; then
        echo "  ❌ Binary not found: $binary"
        return 1
    fi
    
    echo "Checking: $binary"
    echo "----------------------------------------"
    
    # 1. Check if PIE is disabled
    echo -n "  PIE disabled: "
    if file "$binary" | grep -q "pie executable"; then
        echo "❌ FAIL (PIE is enabled)"
    else
        echo "✓ PASS"
    fi
    
    # 2. Check for BuildID
    echo -n "  BuildID present: "
    if file "$binary" | grep -q "BuildID"; then
        echo "✓ PASS"
    else
        echo "❌ FAIL (No BuildID)"
    fi
    
    # 3. Check if statically linked
    echo -n "  Static linking: "
    if file "$binary" | grep -q "statically linked"; then
        echo "✓ PASS"
    else
        echo "❌ FAIL (Not statically linked)"
    fi
    
    # 4. Check hash style (using readelf if available)
    if command -v readelf >/dev/null 2>&1; then
        echo -n "  Hash style: "
        local hash_sections=$(readelf -S "$binary" 2>/dev/null | grep -E "\.hash|\.gnu\.hash" | awk '{print $2}' | tr '\n' ' ')
        if [[ "$hash_sections" == *".hash"* ]] && [[ "$hash_sections" == *".gnu.hash"* ]]; then
            echo "✓ PASS (both .hash and .gnu.hash present)"
        elif [[ "$hash_sections" == *".gnu.hash"* ]]; then
            echo "⚠ WARNING (only .gnu.hash present)"
        elif [[ "$hash_sections" == *".hash"* ]]; then
            echo "⚠ WARNING (only .hash present)"
        else
            echo "❌ FAIL (no hash sections found)"
        fi
    fi
    
    # 5. Check for FORTIFY_SOURCE symbols (should be minimal)
    if command -v nm >/dev/null 2>&1; then
        echo -n "  FORTIFY symbols: "
        local fortify_count=$(nm "$binary" 2>/dev/null | grep -c "__.*_chk" || true)
        if [ "$fortify_count" -eq 0 ]; then
            echo "✓ PASS (no fortify symbols)"
        else
            echo "⚠ WARNING ($fortify_count fortify symbols found)"
        fi
    fi
    
    # 6. Check for GNU_STACK (NX bit)
    if command -v readelf >/dev/null 2>&1; then
        echo -n "  NX bit (GNU_STACK): "
        if readelf -l "$binary" 2>/dev/null | grep -q "GNU_STACK.*RW "; then
            echo "✓ PASS (stack not executable)"
        else
            echo "⚠ WARNING (could not verify NX bit)"
        fi
    fi
    
    echo
}

# Function to test compile flags
test_compile_flags() {
    local test_dir="/tmp/flag-test-$$"
    mkdir -p "$test_dir"
    
    echo "Testing compile flag detection..."
    echo "----------------------------------------"
    
    # Create a simple test program
    cat > "$test_dir/test.c" << 'EOF'
#include <stdio.h>

int main() {
    #ifdef _GNU_SOURCE
    printf("_GNU_SOURCE is defined\n");
    #else
    printf("_GNU_SOURCE is NOT defined\n");
    #endif
    
    #ifdef _FORTIFY_SOURCE
    printf("_FORTIFY_SOURCE = %d\n", _FORTIFY_SOURCE);
    #else
    printf("_FORTIFY_SOURCE is NOT defined\n");
    #endif
    
    return 0;
}
EOF
    
    # Try to compile with the musl flags
    if [ -f "scripts/lib/build_flags.sh" ]; then
        source scripts/lib/build_flags.sh
        
        local cflags=$(get_compile_flags "x86_64" "test")
        local ldflags=$(get_link_flags "x86_64")
        
        echo "Musl CFLAGS: $cflags"
        echo "Musl LDFLAGS: $ldflags"
        echo
        
        # Compile test program if gcc is available
        if command -v gcc >/dev/null 2>&1; then
            if gcc $cflags -o "$test_dir/test_musl" "$test_dir/test.c" $ldflags 2>/dev/null; then
                echo "Test program output (musl flags):"
                "$test_dir/test_musl" || true
                echo
            fi
        fi
    fi
    
    # Try with glibc flags
    if [ -f "scripts/lib/build_flags_glibc.sh" ]; then
        source scripts/lib/build_flags_glibc.sh
        
        local cflags=$(get_glibc_compile_flags "x86_64" "test")
        local ldflags=$(get_glibc_link_flags "x86_64")
        
        echo "Glibc CFLAGS: $cflags"
        echo "Glibc LDFLAGS: $ldflags"
        echo
    fi
    
    rm -rf "$test_dir"
}

# Main test execution
main() {
    # Test flag functions
    test_compile_flags
    
    # Test actual binaries if they exist
    echo "Testing built binaries..."
    echo "========================================"
    echo
    
    # Find a few sample binaries to test
    for arch in x86_64 aarch64 arm32v7le; do
        if [ -d "output/$arch" ]; then
            echo "Architecture: $arch"
            echo "========================================"
            
            # Test a few different tools
            for tool in strace busybox tcpdump ltrace; do
                if [ -f "output/$arch/$tool" ]; then
                    check_binary "output/$arch/$tool" "$arch"
                fi
            done
        fi
    done
    
    # Test shared libraries
    echo "Testing shared libraries..."
    echo "========================================"
    echo
    
    for lib_path in output-preload/glibc/x86_64/*.so output-preload/musl/x86_64/*.so; do
        if [ -f "$lib_path" ]; then
            echo "Checking: $lib_path"
            echo "----------------------------------------"
            
            # Check if PIC is enabled (required for shared libs)
            echo -n "  PIC enabled: "
            if file "$lib_path" | grep -q "shared object"; then
                echo "✓ PASS"
            else
                echo "❌ FAIL (not a shared object)"
            fi
            
            # Check hash style
            if command -v readelf >/dev/null 2>&1; then
                echo -n "  Hash style: "
                local hash_sections=$(readelf -S "$lib_path" 2>/dev/null | grep -E "\.hash|\.gnu\.hash" | awk '{print $2}' | tr '\n' ' ')
                if [[ "$hash_sections" == *".hash"* ]] && [[ "$hash_sections" == *".gnu.hash"* ]]; then
                    echo "✓ PASS (both .hash and .gnu.hash)"
                else
                    echo "⚠ WARNING (missing hash sections)"
                fi
            fi
            
            echo
        fi
    done
}

# Run from the project root
cd "$(dirname "$0")/.."
main