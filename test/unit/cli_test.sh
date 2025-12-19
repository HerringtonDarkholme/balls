#!/usr/bin/env bash
#
# Unit Tests: CLI Dispatcher
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/../test_helper.sh"

echo "Running CLI Tests..."
echo ""

# Setup temp directory for test apps
setup_temp_dir

# Test: Help command
test_start "balls help shows usage"
output=$("$PROJECT_ROOT/balls" help 2>&1)
if assert_contains "$output" "Usage:"; then
    test_pass
else
    test_fail "$output"
fi

test_start "balls --help shows usage"
output=$("$PROJECT_ROOT/balls" --help 2>&1)
if assert_contains "$output" "Commands:"; then
    test_pass
else
    test_fail "$output"
fi

test_start "balls -h shows usage"
output=$("$PROJECT_ROOT/balls" -h 2>&1)
if assert_contains "$output" "Usage:"; then
    test_pass
else
    test_fail "$output"
fi

# Test: Version command
test_start "balls version shows version"
output=$("$PROJECT_ROOT/balls" version 2>&1)
if assert_contains "$output" "v0."; then
    test_pass
else
    test_fail "$output"
fi

test_start "balls --version shows version"
output=$("$PROJECT_ROOT/balls" --version 2>&1)
if assert_contains "$output" "Bash on Balls"; then
    test_pass
else
    test_fail "$output"
fi

test_start "balls -v shows version"
output=$("$PROJECT_ROOT/balls" -v 2>&1)
if assert_contains "$output" "v0."; then
    test_pass
else
    test_fail "$output"
fi

# Test: Unknown command
test_start "unknown command fails with error"
"$PROJECT_ROOT/balls" foobar >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    test_pass
else
    test_fail "Should fail for unknown command"
fi

test_start "unknown command shows error message"
output=$("$PROJECT_ROOT/balls" foobar 2>&1)
if assert_contains "$output" "Unknown command"; then
    test_pass
else
    test_fail "$output"
fi

# Test: New command
test_start "balls new creates directory structure"
cd "$TEMP_DIR"
"$PROJECT_ROOT/balls" new myapp >/dev/null 2>&1
if [[ -d "$TEMP_DIR/myapp" ]]; then
    test_pass
else
    test_fail "myapp directory not created"
fi

test_start "balls new creates app/controllers"
if assert_dir_exists "$TEMP_DIR/myapp/app/controllers"; then
    test_pass
else
    test_fail
fi

test_start "balls new creates app/models"
if assert_dir_exists "$TEMP_DIR/myapp/app/models"; then
    test_pass
else
    test_fail
fi

test_start "balls new creates app/views"
if assert_dir_exists "$TEMP_DIR/myapp/app/views"; then
    test_pass
else
    test_fail
fi

test_start "balls new creates config/routes.sh"
if assert_file_exists "$TEMP_DIR/myapp/config/routes.sh"; then
    test_pass
else
    test_fail
fi

test_start "balls new creates .env"
if assert_file_exists "$TEMP_DIR/myapp/.env"; then
    test_pass
else
    test_fail
fi

test_start "balls new creates home controller"
if assert_file_exists "$TEMP_DIR/myapp/app/controllers/home_controller.sh"; then
    test_pass
else
    test_fail
fi

test_start "balls new creates home view"
if assert_file_exists "$TEMP_DIR/myapp/app/views/home/index.sh.html"; then
    test_pass
else
    test_fail
fi

test_start "balls new creates layout"
if assert_file_exists "$TEMP_DIR/myapp/app/views/layouts/application.sh.html"; then
    test_pass
else
    test_fail
fi

test_start "balls new creates public/style.css"
if assert_file_exists "$TEMP_DIR/myapp/public/style.css"; then
    test_pass
else
    test_fail
fi

test_start "balls new without name fails"
"$PROJECT_ROOT/balls" new 2>/dev/null
if [[ $? -ne 0 ]]; then
    test_pass
else
    test_fail "Should require app name"
fi

test_start "balls new with existing dir fails"
mkdir -p "$TEMP_DIR/existingapp"
"$PROJECT_ROOT/balls" new "$TEMP_DIR/existingapp" 2>/dev/null
if [[ $? -ne 0 ]]; then
    test_pass
else
    test_fail "Should fail when directory exists"
fi

# Test: Short command aliases
test_start "balls n works as new alias"
cd "$TEMP_DIR"
"$PROJECT_ROOT/balls" n shortapp >/dev/null 2>&1
if [[ -d "$TEMP_DIR/shortapp" ]]; then
    test_pass
else
    test_fail "short alias not working"
fi

# Cleanup
cleanup_temp_dir

test_summary
exit $?
