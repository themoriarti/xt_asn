#!/bin/bash

# Master test runner for xt_asn
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}           xt_asn Test Suite Runner             ${NC}"
echo -e "${BLUE}================================================${NC}"
echo

# Function to run a test and track results
run_test() {
    local test_name="$1"
    local test_script="$2"
    local requires_root="$3"
    
    echo -e "${BLUE}Running $test_name...${NC}"
    echo "----------------------------------------"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Check if test requires root
    if [ "$requires_root" = "true" ] && [ $EUID -ne 0 ]; then
        echo -e "${YELLOW}⚠ Skipped: $test_name (requires root access)${NC}"
        echo
        return 0
    fi
    
    # Check if test script exists
    if [ ! -f "$test_script" ]; then
        echo -e "${RED}✗ Error: Test script not found: $test_script${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo
        return 1
    fi
    
    # Run the test
    local start_time=$(date +%s)
    if "$test_script"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${GREEN}✓ $test_name passed (${duration}s)${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${RED}✗ $test_name failed (${duration}s)${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    echo
}

# Pre-flight checks
echo -e "${BLUE}Pre-flight checks...${NC}"
echo "----------------------------------------"

# Check if we're in the right directory
if [ ! -f "$PROJECT_DIR/configure.ac" ]; then
    echo -e "${RED}Error: Not in xt_asn project directory${NC}"
    exit 1
fi

# Check if project is built
if [ ! -f "$PROJECT_DIR/extensions/libxt_asn.so" ]; then
    echo -e "${YELLOW}Warning: Project not built. Building...${NC}"
    cd "$PROJECT_DIR"
    if ./configure --enable-debug && make -j$(nproc); then
        echo -e "${GREEN}✓ Project built successfully${NC}"
    else
        echo -e "${RED}✗ Project build failed${NC}"
        exit 1
    fi
fi

# Check if userspace library is installed
XTABLES_LIB_INSTALLED=false
for location in "/usr/lib/xtables/libxt_asn.so" "/usr/local/lib/xtables/libxt_asn.so" "/usr/lib/x86_64-linux-gnu/xtables/libxt_asn.so"; do
    if [ -f "$location" ]; then
        XTABLES_LIB_INSTALLED=true
        echo -e "${GREEN}✓ Userspace library found at $location${NC}"
        break
    fi
done

if [ "$XTABLES_LIB_INSTALLED" = false ]; then
    echo -e "${YELLOW}Warning: Userspace library not installed. Installing...${NC}"
    cd "$PROJECT_DIR"
    if sudo make install; then
        echo -e "${GREEN}✓ Userspace library installed${NC}"
    else
        echo -e "${RED}✗ Failed to install userspace library${NC}"
        exit 1
    fi
fi

# Check if kernel module is loaded
if lsmod | grep -q xt_asn; then
    echo -e "${GREEN}✓ Kernel module is loaded${NC}"
    KERNEL_MODULE_LOADED=true
else
    echo -e "${YELLOW}! Kernel module not loaded${NC}"
    KERNEL_MODULE_LOADED=false
    
    # Try to load it if we have root and the module exists
    if [ $EUID -eq 0 ] && [ -f "$PROJECT_DIR/extensions/xt_asn.ko" ]; then
        echo -e "${YELLOW}Attempting to load kernel module...${NC}"
        if insmod "$PROJECT_DIR/extensions/xt_asn.ko"; then
            echo -e "${GREEN}✓ Kernel module loaded successfully${NC}"
            KERNEL_MODULE_LOADED=true
        else
            echo -e "${RED}✗ Failed to load kernel module${NC}"
        fi
    fi
fi

# Check if test database exists
if [ -d "/usr/share/xt_asn" ] && [ "$(find /usr/share/xt_asn -name "*.iv4" | wc -l)" -gt 0 ]; then
    echo -e "${GREEN}✓ Test database exists${NC}"
else
    echo -e "${YELLOW}! Test database not found. Creating minimal test database...${NC}"
    if [ $EUID -eq 0 ]; then
        mkdir -p /usr/share/xt_asn/{BE,LE}
        echo "192.0.2.0,192.0.2.255,3221225472,3221225727,15169,Google LLC" | \
            perl "$PROJECT_DIR/asn/xt_asn_build" -D /usr/share/xt_asn
        echo -e "${GREEN}✓ Minimal test database created${NC}"
    else
        echo -e "${YELLOW}! Cannot create test database (requires root)${NC}"
    fi
fi

echo

# Run tests
echo -e "${BLUE}Running test suite...${NC}"
echo "========================================"
echo

# Test 1: Userspace Library Tests
run_test "Userspace Library Tests" "$SCRIPT_DIR/test_userspace.sh" "false"

# Test 2: ASN Data Processing Tests  
run_test "ASN Data Processing Tests" "$SCRIPT_DIR/test_asn_data.sh" "false"

# Test 3: Integration Tests (requires root)
run_test "Integration Tests" "$SCRIPT_DIR/test_integration.sh" "true"

# Test 4: ASN Update Script Tests
run_test "ASN Update Script Tests" "$SCRIPT_DIR/test_asn_update.sh" "false"

# Test 5: Performance Tests (requires root)
run_test "Performance Tests" "$SCRIPT_DIR/test_performance.sh" "true"

# Summary
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}                Test Summary                    ${NC}"
echo -e "${BLUE}================================================${NC}"
echo
echo -e "Tests run:    ${BLUE}$TESTS_RUN${NC}"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    
    # Additional information
    echo
    echo -e "${BLUE}System Information:${NC}"
    echo "Kernel: $(uname -r)"
    echo "iptables: $(iptables --version | head -1)"
    echo "Module loaded: $KERNEL_MODULE_LOADED"
    echo "Database files: $(find /usr/share/xt_asn -name "*.iv*" 2>/dev/null | wc -l)"
    
    exit 0
else
    echo -e "${RED}❌ $TESTS_FAILED test(s) failed!${NC}"
    echo
    echo -e "${YELLOW}Troubleshooting tips:${NC}"
    echo "1. Ensure you have root access for full testing"
    echo "2. Check that kernel headers are installed"
    echo "3. Verify iptables development libraries are available"
    echo "4. Make sure the project is properly built and installed"
    
    exit 1
fi
