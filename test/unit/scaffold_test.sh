#!/usr/bin/env bash
#
# Unit Tests: Scaffold / Directory Structure
#

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source test helper
source "$SCRIPT_DIR/../test_helper.sh"

echo "Running Scaffold Tests..."
echo ""

# Test: Required directories exist
test_start "lib/ directory exists"
if assert_dir_exists "$PROJECT_ROOT/lib"; then
    test_pass
else
    test_fail
fi

test_start "templates/ directory exists"
if assert_dir_exists "$PROJECT_ROOT/templates"; then
    test_pass
else
    test_fail
fi

test_start "example/ directory exists"
if assert_dir_exists "$PROJECT_ROOT/example"; then
    test_pass
else
    test_fail
fi

test_start "test/ directory exists"
if assert_dir_exists "$PROJECT_ROOT/test"; then
    test_pass
else
    test_fail
fi

test_start "test/unit/ directory exists"
if assert_dir_exists "$PROJECT_ROOT/test/unit"; then
    test_pass
else
    test_fail
fi

test_start "test/integration/ directory exists"
if assert_dir_exists "$PROJECT_ROOT/test/integration"; then
    test_pass
else
    test_fail
fi

test_start "test/e2e/ directory exists"
if assert_dir_exists "$PROJECT_ROOT/test/e2e"; then
    test_pass
else
    test_fail
fi

test_start "db/ directory exists"
if assert_dir_exists "$PROJECT_ROOT/db"; then
    test_pass
else
    test_fail
fi

test_start "tmp/cache/ directory exists"
if assert_dir_exists "$PROJECT_ROOT/tmp/cache"; then
    test_pass
else
    test_fail
fi

test_start "log/ directory exists"
if assert_dir_exists "$PROJECT_ROOT/log"; then
    test_pass
else
    test_fail
fi

# Test: Required files exist
test_start ".env.example file exists"
if assert_file_exists "$PROJECT_ROOT/.env.example"; then
    test_pass
else
    test_fail
fi

test_start "README.md file exists"
if assert_file_exists "$PROJECT_ROOT/README.md"; then
    test_pass
else
    test_fail
fi

test_start "balls CLI exists"
if assert_file_exists "$PROJECT_ROOT/balls"; then
    test_pass
else
    test_fail
fi

test_start "balls CLI is executable"
if [[ -x "$PROJECT_ROOT/balls" ]]; then
    test_pass
else
    test_fail "balls is not executable"
fi

# Test: balls CLI basic functionality
test_start "balls --version works"
output=$("$PROJECT_ROOT/balls" --version 2>&1)
if assert_contains "$output" "Bash on Balls"; then
    test_pass
else
    test_fail "$output"
fi

test_start "balls help works"
output=$("$PROJECT_ROOT/balls" help 2>&1)
if assert_contains "$output" "Usage:"; then
    test_pass
else
    test_fail "$output"
fi

test_start "balls unknown command fails"
"$PROJECT_ROOT/balls" unknowncommand >/dev/null 2>&1
if assert_failure $?; then
    test_pass
else
    test_fail "Should have failed for unknown command"
fi

# Print summary
test_summary
exit $?
