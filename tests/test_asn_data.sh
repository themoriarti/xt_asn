#!/bin/bash

# Test script for ASN data processing
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Running ASN data processing tests..."

# Test 1: BGP data conversion tool
test_bgp_conversion() {
    echo "Test 1: BGP data conversion tool"
    
    local build_script="$PROJECT_DIR/asn/xt_asn_build"
    
    if [ -f "$build_script" ]; then
        echo "✓ BGP conversion script exists"
        
        if [ -x "$build_script" ]; then
            echo "✓ BGP conversion script is executable"
        else
            echo "✗ BGP conversion script is not executable"
            return 1
        fi
        
        # Check for required Perl modules
        if perl -e "use Text::CSV_XS; use Getopt::Long; use IO::Handle;" 2>/dev/null; then
            echo "✓ Required Perl modules are available"
        else
            echo "✗ Required Perl modules missing"
            return 1
        fi
    else
        echo "✗ BGP conversion script not found"
        return 1
    fi
}

# Test 2: Create sample test data
create_test_data() {
    local test_dir="$1"
    
    # Create sample CSV data for testing
    cat > "$test_dir/test_asn.csv" << 'EOF'
192.0.2.0,192.0.2.255,3221225472,3221225727,15169,Google LLC
198.51.100.0,198.51.100.255,3325256704,3325256959,8075,Microsoft Corporation
203.0.113.0,203.0.113.255,3405803520,3405803775,13335,Cloudflare Inc
2001:db8::,2001:db8:ffff:ffff:ffff:ffff:ffff:ffff,,,,32934,Facebook Inc
EOF
    
    echo "✓ Created test ASN data"
}

# Test 3: Test data processing
test_data_processing() {
    echo "Test 2: Data processing"
    
    local temp_dir=$(mktemp -d)
    local build_script="$PROJECT_DIR/asn/xt_asn_build"
    
    create_test_data "$temp_dir"
    
    if [ -f "$build_script" ]; then
        # Create output directory
        mkdir -p "$temp_dir/output"
        
        if perl "$build_script" -D "$temp_dir/output" "$temp_dir/test_asn.csv" 2>/dev/null; then
            echo "✓ Data processing completed successfully"
            
            # Check output structure
            if [ -d "$temp_dir/output/LE" ] && [ -d "$temp_dir/output/BE" ]; then
                echo "✓ Endianness directories created"
                
                # Check for generated files
                local le_files=$(find "$temp_dir/output/LE" -name "*.iv4" -o -name "*.iv6" | wc -l)
                local be_files=$(find "$temp_dir/output/BE" -name "*.iv4" -o -name "*.iv6" | wc -l)
                
                if [ $le_files -gt 0 ] && [ $be_files -gt 0 ]; then
                    echo "✓ Database files generated (LE: $le_files, BE: $be_files)"
                else
                    echo "✗ No database files generated"
                    rm -rf "$temp_dir"
                    return 1
                fi
                
                # Check file sizes
                for file in "$temp_dir/output/LE"/*.iv4; do
                    if [ -f "$file" ] && [ -s "$file" ]; then
                        echo "✓ IPv4 database files have content"
                        break
                    fi
                done
                
                for file in "$temp_dir/output/LE"/*.iv6; do
                    if [ -f "$file" ] && [ -s "$file" ]; then
                        echo "✓ IPv6 database files have content"
                        break
                    fi
                done
                
            else
                echo "✗ Output directory structure incorrect"
                rm -rf "$temp_dir"
                return 1
            fi
        else
            echo "✗ Data processing failed"
            rm -rf "$temp_dir"
            return 1
        fi
    else
        echo "✗ Build script not found"
        rm -rf "$temp_dir"
        return 1
    fi
    
    rm -rf "$temp_dir"
}

# Test 4: Update script validation
test_update_scripts() {
    echo "Test 3: Update scripts validation"
    
    local update_script="$PROJECT_DIR/asn/update-asndata.sh"
    local download_script="$PROJECT_DIR/asn/download-asndata.sh"
    
    if [ -f "$update_script" ]; then
        echo "✓ Update script exists"
        
        # Check script syntax
        if bash -n "$update_script"; then
            echo "✓ Update script syntax is valid"
        else
            echo "✗ Update script has syntax errors"
            return 1
        fi
        
        # Check for required tools
        if grep -q "bgpdump" "$update_script"; then
            echo "✓ Update script uses bgpdump"
        else
            echo "✗ Update script missing bgpdump reference"
            return 1
        fi
    else
        echo "✗ Update script not found"
        return 1
    fi
    
    if [ -f "$download_script" ]; then
        echo "✓ Download script exists"
        
        # Check script syntax
        if bash -n "$download_script"; then
            echo "✓ Download script syntax is valid"
        else
            echo "✗ Download script has syntax errors"
            return 1
        fi
    else
        echo "✗ Download script not found"
        return 1
    fi
}

# Test 5: BGP table parser
test_bgp_parser() {
    echo "Test 4: BGP table parser"
    
    local parser_script="$PROJECT_DIR/asn/bgp_table_to_text.pl"
    
    if [ -f "$parser_script" ]; then
        echo "✓ BGP parser script exists"
        
        if perl -c "$parser_script" 2>/dev/null; then
            echo "✓ BGP parser script syntax is valid"
        else
            echo "✗ BGP parser script has syntax errors"
            return 1
        fi
        
        # Check for required Perl modules
        if perl -e "use Net::IP; use Net::Netmask;" 2>/dev/null; then
            echo "✓ BGP parser Perl modules are available"
        else
            echo "! Warning: BGP parser Perl modules missing (Net::IP, Net::Netmask)"
        fi
    else
        echo "✗ BGP parser script not found"
        return 1
    fi
}

# Test 6: Data format validation
test_data_format() {
    echo "Test 5: Data format validation"
    
    local temp_dir=$(mktemp -d)
    local build_script="$PROJECT_DIR/asn/xt_asn_build"
    
    create_test_data "$temp_dir"
    
    # Create output directory
    mkdir -p "$temp_dir/output"
    
    if perl "$build_script" -D "$temp_dir/output" "$temp_dir/test_asn.csv" 2>/dev/null; then
        # Check IPv4 file format
        for file in "$temp_dir/output/LE"/*.iv4; do
            if [ -f "$file" ]; then
                local size=$(stat -c%s "$file")
                local expected_multiple=8  # Each IPv4 range is 8 bytes (2 x 32-bit)
                
                if [ $((size % expected_multiple)) -eq 0 ]; then
                    echo "✓ IPv4 file format correct ($size bytes, $(($size / $expected_multiple)) ranges)"
                else
                    echo "✗ IPv4 file format incorrect (size: $size bytes)"
                    rm -rf "$temp_dir"
                    return 1
                fi
                break
            fi
        done
        
        # Check IPv6 file format
        for file in "$temp_dir/output/LE"/*.iv6; do
            if [ -f "$file" ]; then
                local size=$(stat -c%s "$file")
                local expected_multiple=32  # Each IPv6 range is 32 bytes (2 x 128-bit)
                
                if [ $((size % expected_multiple)) -eq 0 ]; then
                    echo "✓ IPv6 file format correct ($size bytes, $(($size / $expected_multiple)) ranges)"
                else
                    echo "✗ IPv6 file format incorrect (size: $size bytes)"
                    rm -rf "$temp_dir"
                    return 1
                fi
                break
            fi
        done
        
        # Compare LE and BE file sizes (should be identical)
        for le_file in "$temp_dir/output/LE"/*; do
            if [ -f "$le_file" ]; then
                local filename=$(basename "$le_file")
                local be_file="$temp_dir/output/BE/$filename"
                
                if [ -f "$be_file" ]; then
                    local le_size=$(stat -c%s "$le_file")
                    local be_size=$(stat -c%s "$be_file")
                    
                    if [ $le_size -eq $be_size ]; then
                        echo "✓ LE and BE files have matching sizes for $filename"
                    else
                        echo "✗ LE and BE files size mismatch for $filename"
                        rm -rf "$temp_dir"
                        return 1
                    fi
                else
                    echo "✗ Missing BE file for $filename"
                    rm -rf "$temp_dir"
                    return 1
                fi
            fi
        done
    else
        echo "✗ Failed to process test data"
        rm -rf "$temp_dir"
        return 1
    fi
    
    rm -rf "$temp_dir"
}

# Main test execution
main() {
    echo "Starting ASN data processing tests"
    echo "=================================="
    
    # Check for required tools
    if ! command -v perl >/dev/null 2>&1; then
        echo "Error: Perl not found"
        exit 1
    fi
    
    local failed=0
    
    test_bgp_conversion || failed=1
    echo
    
    test_data_processing || failed=1
    echo
    
    test_update_scripts || failed=1
    echo
    
    test_bgp_parser || failed=1
    echo
    
    test_data_format || failed=1
    echo
    
    if [ $failed -eq 0 ]; then
        echo "All ASN data processing tests passed! ✓"
        exit 0
    else
        echo "Some tests failed! ✗"
        exit 1
    fi
}

main "$@"
