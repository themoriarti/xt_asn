#!/bin/bash

# Test script for xt_asn userspace library
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Running userspace library tests..."

# Test 1: Check if library loads correctly
test_library_load() {
    echo "Test 1: Library loading"
    
    if [ -f "/usr/lib/xtables/libxt_asn.so" ] || [ -f "/usr/local/lib/xtables/libxt_asn.so" ]; then
        echo "✓ Library file exists"
    else
        echo "✗ Library file not found"
        return 1
    fi
    
    # Test iptables integration
    if iptables -m asn --help >/dev/null 2>&1; then
        echo "✓ iptables recognizes asn module"
    else
        echo "✗ iptables does not recognize asn module"
        return 1
    fi
}

# Test 2: Parameter parsing
test_parameter_parsing() {
    echo "Test 2: Parameter parsing"
    
    # Test valid ASN numbers
    local test_cases=(
        "--src-asn 15169"
        "--dst-asn 8075,13335"
        "--source-asn 32934"
        "--destination-asn 16509"
    )
    
    for test_case in "${test_cases[@]}"; do
        if iptables -t filter -C INPUT -m asn $test_case -j ACCEPT 2>/dev/null; then
            # Rule exists, remove it first
            iptables -t filter -D INPUT -m asn $test_case -j ACCEPT 2>/dev/null || true
        fi
        
        if iptables -t filter -A INPUT -m asn $test_case -j ACCEPT 2>/dev/null; then
            echo "✓ Valid parameters: $test_case"
            iptables -t filter -D INPUT -m asn $test_case -j ACCEPT 2>/dev/null || true
        else
            echo "✗ Failed to parse: $test_case"
            return 1
        fi
    done
}

# Test 3: Invalid parameters
test_invalid_parameters() {
    echo "Test 3: Invalid parameter handling"
    
    local invalid_cases=(
        "--src-asn"  # Missing value
        "--src-asn abc"  # Non-numeric
        "--src-asn 4294967296"  # Too large for 32-bit
    )
    
    for test_case in "${invalid_cases[@]}"; do
        if iptables -t filter -A INPUT -m asn $test_case -j ACCEPT 2>/dev/null; then
            echo "✗ Should have failed: $test_case"
            iptables -t filter -D INPUT -m asn $test_case -j ACCEPT 2>/dev/null || true
            return 1
        else
            echo "✓ Correctly rejected: $test_case"
        fi
    done
}

# Test 4: Help message
test_help_message() {
    echo "Test 4: Help message"
    
    local help_output=$(iptables -m asn --help 2>&1)
    
    if echo "$help_output" | grep -q "asn match options"; then
        echo "✓ Help message contains expected content"
    else
        echo "✗ Help message missing or incomplete"
        return 1
    fi
    
    if echo "$help_output" | grep -q "src-asn\|source-asn"; then
        echo "✓ Help contains source ASN option"
    else
        echo "✗ Help missing source ASN option"
        return 1
    fi
    
    if echo "$help_output" | grep -q "dst-asn\|destination-asn"; then
        echo "✓ Help contains destination ASN option"
    else
        echo "✗ Help missing destination ASN option"
        return 1
    fi
}

# Main test execution
main() {
    echo "Starting xt_asn userspace library tests"
    echo "======================================="
    
    # Check if we have required privileges
    if [ $EUID -ne 0 ]; then
        echo "Warning: Not running as root. Some tests may fail."
    fi
    
    # Check if iptables is available
    if ! command -v iptables >/dev/null 2>&1; then
        echo "Error: iptables not found"
        exit 1
    fi
    
    local failed=0
    
    test_library_load || failed=1
    echo
    
    test_parameter_parsing || failed=1
    echo
    
    test_invalid_parameters || failed=1
    echo
    
    test_help_message || failed=1
    echo
    
    if [ $failed -eq 0 ]; then
        echo "All userspace library tests passed! ✓"
        exit 0
    else
        echo "Some tests failed! ✗"
        exit 1
    fi
}

main "$@"
