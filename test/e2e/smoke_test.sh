#!/usr/bin/env bash
#
# E2E Smoke Test for Bash on Balls
#
# Tests the full request/response cycle through the server
#

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source test helper
source "$PROJECT_ROOT/test/test_helper.sh"

# Configuration
TEST_PORT=4567
SERVER_PID=""
EXAMPLE_APP="$PROJECT_ROOT/example"

# Cleanup function
cleanup() {
    if [[ -n "$SERVER_PID" ]]; then
        kill "$SERVER_PID" 2>/dev/null || true
        # Also kill any child processes
        pkill -P "$SERVER_PID" 2>/dev/null || true
    fi
    # Clean up any orphaned nc processes on our port
    pkill -f "nc -l $TEST_PORT" 2>/dev/null || true
}

trap cleanup EXIT INT TERM

# Start server in background
start_server() {
    echo "Starting server on port $TEST_PORT..."
    
    # Make sure port is free
    pkill -f "nc -l $TEST_PORT" 2>/dev/null || true
    sleep 0.2
    
    "$PROJECT_ROOT/balls" server "$EXAMPLE_APP" "$TEST_PORT" 2>&1 &
    SERVER_PID=$!
    
    # Wait for server to start
    # Instead of using nc -z (which consumes a connection), 
    # we just wait a fixed time for the server to initialize
    local max_wait=30
    local waited=0
    
    # First, wait for the process to start
    while ! kill -0 "$SERVER_PID" 2>/dev/null; do
        sleep 0.1
        ((waited++)) || true
        if [[ $waited -ge 10 ]]; then
            echo "Server process failed to start"
            return 1
        fi
    done
    
    # Give the server time to set up its listener
    sleep 2
    
    # Verify process is still running
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "Server process died"
        return 1
    fi
    
    echo "Server started (PID: $SERVER_PID)"
    return 0
}

# Make HTTP request with timeout
http_get() {
    local path="$1"
    local timeout="${2:-5}"
    curl -s --max-time "$timeout" "http://127.0.0.1:${TEST_PORT}${path}" 2>/dev/null || echo ""
}

http_post() {
    local path="$1"
    local data="$2"
    local timeout="${3:-5}"
    curl -s --max-time "$timeout" -X POST -d "$data" "http://127.0.0.1:${TEST_PORT}${path}" 2>/dev/null || echo ""
}

# Wait for server to be ready for next request
wait_for_server() {
    sleep 0.3
}

echo ""
echo "================================"
echo "Bash on Balls E2E Smoke Tests"
echo "================================"
echo ""

# Start server
if ! start_server; then
    echo "FATAL: Could not start server"
    exit 1
fi

echo ""

# Test 1: Home page
test_start "GET / returns home page"
response=$(http_get "/")
wait_for_server
if [[ -n "$response" ]] && assert_contains "$response" "Bash on Balls"; then
    test_pass
else
    test_fail "Home page did not contain expected content (got ${#response} bytes)"
fi

# Test 2: Posts index
test_start "GET /posts returns posts list"
response=$(http_get "/posts")
wait_for_server
if [[ -n "$response" ]] && assert_contains "$response" "Posts"; then
    test_pass
else
    test_fail "Posts page did not contain expected content"
fi

# Test 3: Show a post
test_start "GET /posts/1 returns post detail"
response=$(http_get "/posts/1")
wait_for_server
if [[ -n "$response" ]] && assert_contains "$response" "Welcome to Bash on Balls"; then
    test_pass
else
    test_fail "Post show page did not contain expected content"
fi

# Test 4: New post form
test_start "GET /posts/new returns new post form"
response=$(http_get "/posts/new")
wait_for_server
if [[ -n "$response" ]] && assert_contains "$response" "form"; then
    test_pass
else
    test_fail "New post page did not contain form"
fi

# Test 5: Edit post form
test_start "GET /posts/1/edit returns edit form"
response=$(http_get "/posts/1/edit")
wait_for_server
if [[ -n "$response" ]] && assert_contains "$response" "Edit"; then
    test_pass
else
    test_fail "Edit page did not contain expected content"
fi

# Test 6: Static file serving
test_start "GET /style.css returns CSS file"
response=$(http_get "/style.css")
wait_for_server
if [[ -n "$response" ]] && assert_contains "$response" "font-family"; then
    test_pass
else
    test_fail "CSS file did not contain expected content"
fi

# Test 7: 404 for unknown routes
test_start "GET /unknown returns 404"
response=$(http_get "/unknown")
wait_for_server
if [[ -n "$response" ]] && assert_contains "$response" "404"; then
    test_pass
else
    test_fail "Unknown route did not return 404"
fi

# Print summary
test_summary
exit $?
