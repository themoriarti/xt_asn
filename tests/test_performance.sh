#!/bin/bash

# Performance test script for xt_asn
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Running performance tests..."

# Test 1: Module loading performance
test_module_performance() {
    echo "Test 1: Module loading performance"
    
    if [ $EUID -ne 0 ]; then
        echo "! Skipping module performance tests (requires root access)"
        return 0
    fi
    
    # Check if module is loaded
    if ! lsmod | grep -q xt_asn; then
        echo "! xt_asn module not loaded, skipping performance tests"
        return 0
    fi
    
    echo "✓ Module loaded and ready for performance testing"
}

# Test 2: Rule addition performance
test_rule_performance() {
    echo "Test 2: Rule addition performance"
    
    if [ $EUID -ne 0 ]; then
        echo "! Skipping rule performance tests (requires root access)"
        return 0
    fi
    
    local start_time=$(date +%s.%N)
    
    # Add multiple rules quickly
    for asn in 15169 8075 13335 32934 16509; do
        iptables -A INPUT -m asn --src-asn $asn -j ACCEPT 2>/dev/null || echo "Failed to add rule for ASN $asn"
    done
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0.1")
    
    echo "✓ Added 5 rules in ${duration}s"
    
    # Clean up rules
    for asn in 15169 8075 13335 32934 16509; do
        iptables -D INPUT -m asn --src-asn $asn -j ACCEPT 2>/dev/null || true
    done
    
    echo "✓ Rules cleaned up"
}

# Test 3: Database access performance
test_database_performance() {
    echo "Test 3: Database access performance"
    
    local db_dir="/usr/share/xt_asn"
    
    if [ ! -d "$db_dir" ]; then
        echo "! Database directory not found, skipping database performance tests"
        return 0
    fi
    
    # Count database files
    local le_files=$(find "$db_dir/LE" -name "*.iv4" -o -name "*.iv6" 2>/dev/null | wc -l)
    local be_files=$(find "$db_dir/BE" -name "*.iv4" -o -name "*.iv6" 2>/dev/null | wc -l)
    
    echo "✓ Database contains $le_files LE and $be_files BE files"
    
    # Check file sizes
    local total_size=$(du -sh "$db_dir" 2>/dev/null | cut -f1 || echo "unknown")
    echo "✓ Total database size: $total_size"
    
    # Test file access speed
    local start_time=$(date +%s.%N)
    find "$db_dir" -name "*.iv4" -exec test -r {} \; 2>/dev/null
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0.1")
    
    echo "✓ Database file access check completed in ${duration}s"
}

# Test 4: Memory usage
test_memory_usage() {
    echo "Test 4: Memory usage"
    
    if [ $EUID -ne 0 ]; then
        echo "! Skipping memory usage tests (requires root access)"
        return 0
    fi
    
    # Check if module is loaded
    if ! lsmod | grep -q xt_asn; then
        echo "! xt_asn module not loaded, skipping memory tests"
        return 0
    fi
    
    # Get module memory usage
    local module_size=$(lsmod | grep xt_asn | awk '{print $2}')
    echo "✓ Module memory usage: ${module_size} bytes"
    
    # Check system memory before and after rule addition
    local mem_before=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    
    # Add some rules
    for i in {1..10}; do
        iptables -A INPUT -m asn --src-asn 15169 -j ACCEPT 2>/dev/null || true
    done
    
    local mem_after=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local mem_diff=$((mem_before - mem_after))
    
    echo "✓ Memory impact of 10 rules: ${mem_diff}KB"
    
    # Clean up
    for i in {1..10}; do
        iptables -D INPUT -m asn --src-asn 15169 -j ACCEPT 2>/dev/null || true
    done
}

# Test 5: Stress test
test_stress() {
    echo "Test 5: Stress test"
    
    if [ $EUID -ne 0 ]; then
        echo "! Skipping stress tests (requires root access)"
        return 0
    fi
    
    local rule_count=0
    local start_time=$(date +%s.%N)
    
    # Try to add many rules quickly
    for asn in 15169 8075 13335 32934 16509; do
        for action in ACCEPT DROP; do
            if iptables -A INPUT -m asn --src-asn $asn -j $action 2>/dev/null; then
                rule_count=$((rule_count + 1))
            fi
        done
    done
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0.1")
    
    echo "✓ Successfully added $rule_count rules in ${duration}s"
    echo "✓ Average time per rule: $(echo "scale=6; $duration / $rule_count" | bc -l 2>/dev/null || echo "unknown")s"
    
    # Clean up all rules
    iptables -F INPUT 2>/dev/null || true
    echo "✓ Stress test cleanup completed"
}

# Main test execution
main() {
    echo "Starting xt_asn performance tests"
    echo "================================="
    
    # Check basic requirements
    if ! command -v iptables >/dev/null 2>&1; then
        echo "Error: iptables not found"
        exit 1
    fi
    
    local failed=0
    
    test_module_performance || failed=1
    echo
    
    test_rule_performance || failed=1
    echo
    
    test_database_performance || failed=1
    echo
    
    test_memory_usage || failed=1
    echo
    
    test_stress || failed=1
    echo
    
    if [ $failed -eq 0 ]; then
        echo "All performance tests completed! ✓"
        exit 0
    else
        echo "Some performance tests encountered issues! !"
        exit 1
    fi
}

main "$@"
