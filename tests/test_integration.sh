#!/bin/bash

# Integration test script for xt_asn
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Running integration tests..."

# Test 1: Kernel module loading
test_module_loading() {
    echo "Test 1: Kernel module loading"
    
    # Check if module is loaded
    if lsmod | grep -q xt_asn; then
        echo "✓ Kernel module is loaded"
    else
        echo "Attempting to load kernel module..."
        if modprobe xt_asn 2>/dev/null; then
            echo "✓ Successfully loaded kernel module"
        else
            echo "✗ Failed to load kernel module"
            return 1
        fi
    fi
    
    # Check module info
    if modinfo xt_asn >/dev/null 2>&1; then
        echo "✓ Module info available"
        modinfo xt_asn | grep -E "^(description|author|license|version):"
    else
        echo "✗ Module info not available"
        return 1
    fi
}

# Test 2: Basic iptables rule functionality
test_basic_rules() {
    echo "Test 2: Basic iptables rules"
    
    # Test adding a simple rule
    if iptables -t filter -C INPUT -m asn --src-asn 15169 -j ACCEPT 2>/dev/null; then
        iptables -t filter -D INPUT -m asn --src-asn 15169 -j ACCEPT
    fi
    
    if iptables -t filter -A INPUT -m asn --src-asn 15169 -j ACCEPT; then
        echo "✓ Successfully added ASN rule"
        
        # Check if rule is in table
        if iptables -t filter -C INPUT -m asn --src-asn 15169 -j ACCEPT; then
            echo "✓ Rule is present in iptables"
            iptables -t filter -D INPUT -m asn --src-asn 15169 -j ACCEPT
        else
            echo "✗ Rule not found in iptables"
            return 1
        fi
    else
        echo "✗ Failed to add ASN rule"
        return 1
    fi
}

# Test 3: Multiple ASN rule
test_multiple_asn() {
    echo "Test 3: Multiple ASN rules"
    
    local rule="INPUT -m asn --src-asn 15169,8075,13335 -j DROP"
    
    # Clean up any existing rule
    iptables -t filter -D $rule 2>/dev/null || true
    
    if iptables -t filter -A $rule; then
        echo "✓ Successfully added multiple ASN rule"
        
        if iptables -t filter -C $rule; then
            echo "✓ Multiple ASN rule is active"
            iptables -t filter -D $rule
        else
            echo "✗ Multiple ASN rule not found"
            return 1
        fi
    else
        echo "✗ Failed to add multiple ASN rule"
        return 1
    fi
}

# Test 4: Rule persistence and save/restore
test_rule_persistence() {
    echo "Test 4: Rule persistence"
    
    local test_rule="INPUT -m asn --dst-asn 32934 -j LOG --log-prefix 'ASN-TEST: '"
    
    # Add test rule
    iptables -t filter -D $test_rule 2>/dev/null || true
    iptables -t filter -A $test_rule
    
    # Save rules to temporary file
    local temp_file=$(mktemp)
    if iptables-save > "$temp_file"; then
        echo "✓ Rules saved successfully"
        
        # Check if our rule is in the save file
        if grep -q "asn.*32934" "$temp_file"; then
            echo "✓ ASN rule found in saved rules"
        else
            echo "✗ ASN rule not found in saved rules"
            rm -f "$temp_file"
            iptables -t filter -D $test_rule 2>/dev/null || true
            return 1
        fi
        
        # Remove rule and restore
        iptables -t filter -D $test_rule
        
        if iptables-restore < "$temp_file"; then
            echo "✓ Rules restored successfully"
            
            # Check if rule is back
            if iptables -t filter -C $test_rule 2>/dev/null; then
                echo "✓ ASN rule restored correctly"
                iptables -t filter -D $test_rule
            else
                echo "✗ ASN rule not restored"
                rm -f "$temp_file"
                return 1
            fi
        else
            echo "✗ Failed to restore rules"
            rm -f "$temp_file"
            return 1
        fi
        
        rm -f "$temp_file"
    else
        echo "✗ Failed to save rules"
        iptables -t filter -D $test_rule 2>/dev/null || true
        return 1
    fi
}

# Test 5: Database file access
test_database_access() {
    echo "Test 5: Database file access"
    
    local db_dir="/usr/share/xt_asn"
    
    if [ -d "$db_dir" ]; then
        echo "✓ Database directory exists: $db_dir"
        
        # Check for endianness directories
        if [ -d "$db_dir/LE" ] && [ -d "$db_dir/BE" ]; then
            echo "✓ Endianness directories exist"
            
            # Count database files
            local le_files=$(find "$db_dir/LE" -name "*.iv4" -o -name "*.iv6" | wc -l)
            local be_files=$(find "$db_dir/BE" -name "*.iv4" -o -name "*.iv6" | wc -l)
            
            echo "Database files: LE=$le_files, BE=$be_files"
            
            if [ $le_files -gt 0 ] && [ $be_files -gt 0 ]; then
                echo "✓ Database files are present"
            else
                echo "! Warning: No database files found (run download-asndata.sh)"
            fi
        else
            echo "✗ Endianness directories missing"
            return 1
        fi
    else
        echo "! Warning: Database directory not found: $db_dir"
        echo "  This is expected if ASN data hasn't been downloaded yet"
    fi
}

# Test 6: Error handling
test_error_handling() {
    echo "Test 6: Error handling"
    
    # Test with non-existent ASN (should not cause system crash)
    local test_rule="INPUT -m asn --src-asn 999999 -j ACCEPT"
    
    iptables -t filter -D $test_rule 2>/dev/null || true
    
    if iptables -t filter -A $test_rule 2>/dev/null; then
        echo "✓ System handles non-existent ASN gracefully"
        iptables -t filter -D $test_rule
        
        # Check kernel logs for errors
        local recent_errors=$(dmesg | tail -20 | grep -i "xt_asn.*error" || true)
        if [ -z "$recent_errors" ]; then
            echo "✓ No kernel errors in recent logs"
        else
            echo "! Warning: Found recent kernel errors:"
            echo "$recent_errors"
        fi
    else
        echo "✗ Failed to handle non-existent ASN"
        return 1
    fi
}

# Main test execution
main() {
    echo "Starting xt_asn integration tests"
    echo "================================="
    
    # Check if we have required privileges
    if [ $EUID -ne 0 ]; then
        echo "Error: Integration tests require root privileges"
        exit 1
    fi
    
    # Check if iptables is available
    if ! command -v iptables >/dev/null 2>&1; then
        echo "Error: iptables not found"
        exit 1
    fi
    
    local failed=0
    
    test_module_loading || failed=1
    echo
    
    test_basic_rules || failed=1
    echo
    
    test_multiple_asn || failed=1
    echo
    
    test_rule_persistence || failed=1
    echo
    
    test_database_access || failed=1
    echo
    
    test_error_handling || failed=1
    echo
    
    if [ $failed -eq 0 ]; then
        echo "All integration tests passed! ✓"
        exit 0
    else
        echo "Some tests failed! ✗"
        exit 1
    fi
}

main "$@"
