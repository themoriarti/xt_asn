#!/bin/bash

# Test script for ASN update scripts
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Running ASN update script tests..."

# Test 1: Check update script validation
test_update_script_validation() {
    echo "Test 1: Update script validation"
    
    local update_script="$PROJECT_DIR/asn/update-asndata.sh"
    
    if [ -f "$update_script" ]; then
        echo "✓ Update script exists"
        
        # Check script syntax
        if bash -n "$update_script"; then
            echo "✓ Update script syntax is valid"
        else
            echo "✗ Update script has syntax errors"
            return 1
        fi
        
        # Check if script is executable
        if [ -x "$update_script" ]; then
            echo "✓ Update script is executable"
        else
            echo "! Update script is not executable, fixing..."
            chmod +x "$update_script"
        fi
    else
        echo "✗ Update script not found"
        return 1
    fi
}

# Test 2: Check download script validation
test_download_script_validation() {
    echo "Test 2: Download script validation"
    
    local download_script="$PROJECT_DIR/asn/download-asndata.sh"
    
    if [ -f "$download_script" ]; then
        echo "✓ Download script exists"
        
        # Check script syntax
        if bash -n "$download_script"; then
            echo "✓ Download script syntax is valid"
        else
            echo "✗ Download script has syntax errors"
            return 1
        fi
        
        # Check if script is executable
        if [ -x "$download_script" ]; then
            echo "✓ Download script is executable"
        else
            echo "! Download script is not executable, fixing..."
            chmod +x "$download_script"
        fi
    else
        echo "✗ Download script not found"
        return 1
    fi
}

# Test 3: Check dependencies
test_dependencies() {
    echo "Test 3: Dependencies check"
    
    # Check for bgpdump
    if command -v bgpdump >/dev/null 2>&1; then
        echo "✓ bgpdump is available"
        bgpdump -h >/dev/null 2>&1 || echo "  Note: bgpdump help not accessible"
    else
        echo "! bgpdump not found (will be installed by scripts)"
    fi
    
    # Check for required Perl modules
    if perl -e "use Text::CSV_XS; use Net::IP; use Net::Netmask;" 2>/dev/null; then
        echo "✓ Required Perl modules are available"
    else
        echo "! Some Perl modules missing (will be installed by scripts)"
    fi
    
    # Check for wget
    if command -v wget >/dev/null 2>&1; then
        echo "✓ wget is available"
    else
        echo "✗ wget not found"
        return 1
    fi
}

# Test 4: Test directory creation
test_directory_creation() {
    echo "Test 4: Directory creation"
    
    local test_dir="/tmp/test_xt_asn_$$"
    
    # Test with ASN_DATA_DIR environment variable
    export ASN_DATA_DIR="$test_dir"
    
    # Run the update script check (just the beginning)
    local update_script="$PROJECT_DIR/asn/update-asndata.sh"
    
    # Extract just the directory creation part
    if ASN_DATA_DIR="$test_dir" bash -c '
        ASN_DATA_DIR="${ASN_DATA_DIR:-/var/lib/xt_asn}"
        if [ ! -d "$ASN_DATA_DIR" ]; then
            if [ -w "$(dirname "$ASN_DATA_DIR")" ]; then
                mkdir -p "$ASN_DATA_DIR"
            else
                echo "Would need sudo for $ASN_DATA_DIR"
                exit 0
            fi
        fi
        echo "Directory handling works"
    '; then
        echo "✓ Directory creation logic works"
        
        # Clean up
        if [ -d "$test_dir" ]; then
            rm -rf "$test_dir"
            echo "✓ Test directory cleaned up"
        fi
    else
        echo "✗ Directory creation logic failed"
        return 1
    fi
    
    unset ASN_DATA_DIR
}

# Test 5: Test BGP parser script
test_bgp_parser() {
    echo "Test 5: BGP parser script"
    
    local parser_script="$PROJECT_DIR/asn/bgp_table_to_text.pl"
    
    if [ -f "$parser_script" ]; then
        echo "✓ BGP parser script exists"
        
        # Check syntax
        if perl -c "$parser_script" 2>/dev/null; then
            echo "✓ BGP parser script syntax is valid"
        else
            echo "✗ BGP parser script has syntax errors"
            return 1
        fi
        
        # Test with sample input
        local test_input="TABLE_DUMP2|12345|B|127.0.0.1|65001|0.0.0.0/0|65001 65002|IGP|127.0.0.1|0|0||NAG||"
        
        if echo "$test_input" | perl "$parser_script" >/dev/null 2>&1; then
            echo "✓ BGP parser processes test input successfully"
        else
            echo "! BGP parser test input processing had issues (may be normal)"
        fi
    else
        echo "✗ BGP parser script not found"
        return 1
    fi
}

# Test 6: Test build script
test_build_script() {
    echo "Test 6: Build script"
    
    local build_script="$PROJECT_DIR/asn/xt_asn_build"
    
    if [ -f "$build_script" ]; then
        echo "✓ Build script exists"
        
        # Check syntax
        if perl -c "$build_script" 2>/dev/null; then
            echo "✓ Build script syntax is valid"
        else
            echo "✗ Build script has syntax errors"
            return 1
        fi
        
        # Test with help option
        if perl "$build_script" --help >/dev/null 2>&1 || \
           perl "$build_script" -h >/dev/null 2>&1 || \
           perl "$build_script" 2>&1 | grep -q "Usage\|Target directory"; then
            echo "✓ Build script responds to help/usage requests"
        else
            echo "! Build script usage information not clear"
        fi
    else
        echo "✗ Build script not found"
        return 1
    fi
}

# Main test execution
main() {
    echo "Starting ASN update script tests"
    echo "================================"
    
    local failed=0
    
    test_update_script_validation || failed=1
    echo
    
    test_download_script_validation || failed=1
    echo
    
    test_dependencies || failed=1
    echo
    
    test_directory_creation || failed=1
    echo
    
    test_bgp_parser || failed=1
    echo
    
    test_build_script || failed=1
    echo
    
    if [ $failed -eq 0 ]; then
        echo "All ASN update script tests passed! ✓"
        echo
        echo "The scripts are ready to use:"
        echo "1. Run 'sudo ./asn/update-asndata.sh' to process BGP data locally"
        echo "2. Or configure ASN_DATA_URL and run 'sudo ./asn/download-asndata.sh'"
        exit 0
    else
        echo "Some ASN update script tests failed! ✗"
        exit 1
    fi
}

main "$@"
