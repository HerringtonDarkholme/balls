#!/usr/bin/env bash
#
# Test Helper - Common test utilities
#

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_TEST=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Start a test
test_start() {
    CURRENT_TEST="$1"
    ((TESTS_RUN++))
    printf "  Testing: %s ... " "$1"
}

# Pass a test
test_pass() {
    ((TESTS_PASSED++))
    printf "${GREEN}PASS${NC}\n"
}

# Fail a test
test_fail() {
    local message="$1"
    ((TESTS_FAILED++))
    printf "${RED}FAIL${NC}\n"
    [[ -n "$message" ]] && printf "    ${RED}→ %s${NC}\n" "$message"
}

# Assert equality
assert_equal() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Expected '$expected', got '$actual'}"
    
    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        echo "$message"
        return 1
    fi
}

# Assert string contains
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Expected to contain '$needle'}"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        return 0
    else
        echo "$message"
        return 1
    fi
}

# Assert file exists
assert_file_exists() {
    local file="$1"
    local message="${2:-File '$file' does not exist}"
    
    if [[ -f "$file" ]]; then
        return 0
    else
        echo "$message"
        return 1
    fi
}

# Assert directory exists
assert_dir_exists() {
    local dir="$1"
    local message="${2:-Directory '$dir' does not exist}"
    
    if [[ -d "$dir" ]]; then
        return 0
    else
        echo "$message"
        return 1
    fi
}

# Assert command succeeds
assert_success() {
    local message="${1:-Command failed}"
    
    if [[ $? -eq 0 ]]; then
        return 0
    else
        echo "$message"
        return 1
    fi
}

# Assert command fails
assert_failure() {
    local exit_code="$1"
    local message="${2:-Expected command to fail}"
    
    if [[ $exit_code -ne 0 ]]; then
        return 0
    else
        echo "$message"
        return 1
    fi
}

# Assert not empty
assert_not_empty() {
    local value="$1"
    local message="${2:-Expected non-empty value}"
    
    if [[ -n "$value" ]]; then
        return 0
    else
        echo "$message"
        return 1
    fi
}

# Print test summary
test_summary() {
    echo ""
    echo "================================"
    echo "Test Results:"
    echo "  Total:  $TESTS_RUN"
    printf "  ${GREEN}Passed: $TESTS_PASSED${NC}\n"
    if [[ $TESTS_FAILED -gt 0 ]]; then
        printf "  ${RED}Failed: $TESTS_FAILED${NC}\n"
    else
        echo "  Failed: 0"
    fi
    echo "================================"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Create temp directory for tests
setup_temp_dir() {
    TEMP_DIR=$(mktemp -d)
    export TEMP_DIR
}

# Cleanup temp directory
cleanup_temp_dir() {
    [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
}
