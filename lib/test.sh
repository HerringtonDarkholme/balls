#!/usr/bin/env bash
#
# Bash on Balls - Test Runner
#
# Discovers and runs tests in the test/ directory
#

# Colors for output (if terminal supports it)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    BOLD=''
    NC=''
fi

# Counters
TOTAL_FILES=0
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0
FAILED_FILES=()

# Run a single test file
run_test_file() {
    local test_file="$1"
    local output
    local exit_code
    
    printf "${BLUE}Running:${NC} %s\n" "$test_file"
    
    # Run test and capture output and exit code
    output=$(bash "$test_file" 2>&1)
    exit_code=$?
    
    ((TOTAL_FILES++))
    
    # Parse test counts from output
    local file_tests=0
    local file_passed=0
    local file_failed=0
    
    # Look for test summary in output
    if [[ "$output" =~ Total:\ +([0-9]+) ]]; then
        file_tests="${BASH_REMATCH[1]}"
    fi
    if [[ "$output" =~ Passed:\ +([0-9]+) ]]; then
        file_passed="${BASH_REMATCH[1]}"
    fi
    if [[ "$output" =~ Failed:\ +([0-9]+) ]]; then
        file_failed="${BASH_REMATCH[1]}"
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + file_tests))
    TOTAL_PASSED=$((TOTAL_PASSED + file_passed))
    TOTAL_FAILED=$((TOTAL_FAILED + file_failed))
    
    # Show individual test results (indented)
    echo "$output" | grep -E "Testing:|PASS|FAIL|→" | sed 's/^/  /'
    
    if [[ $exit_code -ne 0 ]] || [[ $file_failed -gt 0 ]]; then
        printf "  ${RED}File result: FAILED${NC} ($file_passed/$file_tests passed)\n"
        FAILED_FILES+=("$test_file")
    else
        printf "  ${GREEN}File result: PASSED${NC} ($file_passed/$file_tests passed)\n"
    fi
    echo ""
    
    return $exit_code
}

# Discover and run tests
run_tests() {
    local test_path="${1:-test}"
    local pattern="${2:-*_test.sh}"
    local start_time
    local end_time
    local duration
    
    start_time=$(date +%s)
    
    echo ""
    printf "${BOLD}Bash on Balls Test Runner${NC}\n"
    echo "================================"
    echo ""
    
    # Handle single file
    if [[ -f "$test_path" ]]; then
        run_test_file "$test_path"
    elif [[ -d "$test_path" ]]; then
        # Find all test files
        local test_files=()
        
        # Use find to get all test files (works with bash 3.2)
        while IFS= read -r -d '' file; do
            test_files+=("$file")
        done < <(find "$test_path" -name "$pattern" -type f -print0 2>/dev/null | sort -z)
        
        if [[ ${#test_files[@]} -eq 0 ]]; then
            printf "${YELLOW}No test files found matching '$pattern' in '$test_path'${NC}\n"
            return 0
        fi
        
        printf "Found ${BOLD}%d${NC} test file(s)\n\n" "${#test_files[@]}"
        
        # Run each test file
        for test_file in "${test_files[@]}"; do
            run_test_file "$test_file"
        done
    else
        printf "${RED}Error: Test path '$test_path' not found${NC}\n"
        return 1
    fi
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    # Print summary
    echo "================================"
    printf "${BOLD}Test Summary${NC}\n"
    echo "================================"
    printf "  Files:  %d\n" "$TOTAL_FILES"
    printf "  Tests:  %d\n" "$TOTAL_TESTS"
    printf "  ${GREEN}Passed: %d${NC}\n" "$TOTAL_PASSED"
    
    if [[ $TOTAL_FAILED -gt 0 ]]; then
        printf "  ${RED}Failed: %d${NC}\n" "$TOTAL_FAILED"
    else
        printf "  Failed: 0\n"
    fi
    
    printf "  Time:   %ds\n" "$duration"
    echo "================================"
    
    # Show failed files if any
    if [[ ${#FAILED_FILES[@]} -gt 0 ]]; then
        echo ""
        printf "${RED}Failed test files:${NC}\n"
        for f in "${FAILED_FILES[@]}"; do
            printf "  - %s\n" "$f"
        done
    fi
    
    echo ""
    
    # Exit with appropriate code
    if [[ $TOTAL_FAILED -gt 0 ]]; then
        printf "${RED}FAILED${NC}\n"
        return 1
    else
        printf "${GREEN}ALL TESTS PASSED${NC}\n"
        return 0
    fi
}
