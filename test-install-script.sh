#!/bin/bash

# Test script to validate the Proxmox installation script
# This script tests the structure and syntax without actually running the installation

set -e

SCRIPT_PATH="proxmox-financial-dashboard.sh"
TEST_RESULTS=()

# Function to run test and record result
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo "Testing: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo "✓ PASS: $test_name"
        TEST_RESULTS+=("PASS: $test_name")
    else
        echo "✗ FAIL: $test_name"
        TEST_RESULTS+=("FAIL: $test_name")
    fi
}

echo "=== Proxmox Financial Dashboard Installation Script Tests ==="
echo

# Test 1: Script exists and is executable
run_test "Script exists and is executable" "test -x $SCRIPT_PATH"

# Test 2: Script has no syntax errors
run_test "Script syntax is valid" "bash -n $SCRIPT_PATH"

# Test 3: Script doesn't use sudo
run_test "Script doesn't use sudo" "! grep -q 'sudo' $SCRIPT_PATH"

# Test 4: Script doesn't use su
run_test "Script doesn't use su" "! grep -q '^su ' $SCRIPT_PATH"

# Test 5: Script doesn't use git
run_test "Script doesn't use git" "! grep -q 'git ' $SCRIPT_PATH"

# Test 6: Script uses curl for downloads
run_test "Script uses curl for downloads" "grep -q 'curl' $SCRIPT_PATH"

# Test 7: Script has proper error handling
run_test "Script has error handling" "grep -q 'set -e' $SCRIPT_PATH"

# Test 8: Script has trap for error handling
run_test "Script has error trap" "grep -q 'trap.*ERR' $SCRIPT_PATH"

# Test 9: Script checks for Proxmox environment
run_test "Script checks Proxmox environment" "grep -q 'check_proxmox' $SCRIPT_PATH"

# Test 10: Script checks for template
run_test "Script checks for template" "grep -q 'check_template' $SCRIPT_PATH"

# Test 11: Script creates systemd service
run_test "Script creates systemd service" "grep -q 'systemd' $SCRIPT_PATH"

# Test 12: Script configures firewall
run_test "Script configures firewall" "grep -q 'ufw' $SCRIPT_PATH"

# Test 13: Script installs Node.js
run_test "Script installs Node.js" "grep -q 'nodejs' $SCRIPT_PATH"

# Test 14: Script downloads application files
run_test "Script downloads application files" "grep -q 'raw.githubusercontent.com' $SCRIPT_PATH"

# Test 15: Script has colored output functions
run_test "Script has colored output" "grep -q 'RED=\|GREEN=\|YELLOW=\|BLUE=' $SCRIPT_PATH"

echo
echo "=== Test Results Summary ==="
for result in "${TEST_RESULTS[@]}"; do
    echo "$result"
done

# Count passes and failures
PASS_COUNT=$(printf '%s\n' "${TEST_RESULTS[@]}" | grep -c "PASS" || true)
FAIL_COUNT=$(printf '%s\n' "${TEST_RESULTS[@]}" | grep -c "FAIL" || true)
TOTAL_COUNT=$((PASS_COUNT + FAIL_COUNT))

echo
echo "Total Tests: $TOTAL_COUNT"
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"

if [[ $FAIL_COUNT -eq 0 ]]; then
    echo "🎉 All tests passed! The installation script is ready."
    exit 0
else
    echo "❌ Some tests failed. Please review the script."
    exit 1
fi
