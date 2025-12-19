#!/usr/bin/env bash
#
# Unit Tests: Controller Runtime
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/../test_helper.sh"
source "$PROJECT_ROOT/lib/controller.sh"
source "$PROJECT_ROOT/lib/view.sh"

echo "Running Controller Tests..."
echo ""

# Setup temp app for testing
setup_temp_dir
mkdir -p "$TEMP_DIR/app/controllers"
mkdir -p "$TEMP_DIR/app/views/test"
mkdir -p "$TEMP_DIR/app/views/layouts"

# Create a test controller
cat > "$TEMP_DIR/app/controllers/test_controller.sh" << 'EOF'
#!/usr/bin/env bash

index_action() {
    title="Test Index"
    render "test/index"
}

show_action() {
    item_id=$(param "id")
    render_html "<h1>Showing item ${item_id}</h1>"
}

create_action() {
    set_flash notice "Created successfully"
    redirect_to "/test"
}

protected_action() {
    render_text "You have access"
}

before_action "require_auth" only="protected"

require_auth() {
    if [[ -z "$CURRENT_USER" ]]; then
        redirect_to "/login"
        return 1
    fi
    return 0
}
EOF

# Create test view
cat > "$TEMP_DIR/app/views/test/index.sh.html" << 'EOF'
<h1>{{title}}</h1>
<p>This is the test index page</p>
EOF

# Create layout
cat > "$TEMP_DIR/app/views/layouts/application.sh.html" << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Test</title></head>
<body>{{yield}}</body>
</html>
EOF

APP_PATH="$TEMP_DIR"

# Test: Response functions
test_start "reset_response clears state"
RESPONSE_STATUS="500 Error"
RESPONSE_BODY="old body"
reset_response
if [[ "$RESPONSE_STATUS" == "200 OK" ]] && [[ -z "$RESPONSE_BODY" ]]; then
    test_pass
else
    test_fail "Status: $RESPONSE_STATUS, Body: $RESPONSE_BODY"
fi

test_start "status sets response status"
status 404 "Not Found"
if [[ "$RESPONSE_STATUS" == "404 Not Found" ]]; then
    test_pass
else
    test_fail "$RESPONSE_STATUS"
fi

test_start "header adds response header"
reset_response
header "X-Custom" "test-value"
if [[ "$RESPONSE_HEADERS" == *"X-Custom: test-value"* ]]; then
    test_pass
else
    test_fail "$RESPONSE_HEADERS"
fi

# Test: Render functions
test_start "render_text sets body and content type"
reset_response
render_text "Hello World"
if [[ "$RESPONSE_BODY" == "Hello World" ]] && [[ "$RESPONSE_HEADERS" == *"text/plain"* ]]; then
    test_pass
else
    test_fail "Body: $RESPONSE_BODY, Headers: $RESPONSE_HEADERS"
fi

test_start "render_json sets body and content type"
reset_response
render_json '{"status":"ok"}'
if [[ "$RESPONSE_BODY" == '{"status":"ok"}' ]] && [[ "$RESPONSE_HEADERS" == *"application/json"* ]]; then
    test_pass
else
    test_fail "Body: $RESPONSE_BODY, Headers: $RESPONSE_HEADERS"
fi

test_start "render_html sets body and content type"
reset_response
render_html "<h1>Test</h1>"
if [[ "$RESPONSE_BODY" == "<h1>Test</h1>" ]] && [[ "$RESPONSE_HEADERS" == *"text/html"* ]]; then
    test_pass
else
    test_fail "Body: $RESPONSE_BODY, Headers: $RESPONSE_HEADERS"
fi

# Test: Redirect
test_start "redirect_to sets location header"
reset_response
redirect_to "/posts"
if [[ "$RESPONSE_HEADERS" == *"Location: /posts"* ]]; then
    test_pass
else
    test_fail "$RESPONSE_HEADERS"
fi

test_start "redirect_to sets 302 status by default"
reset_response
redirect_to "/posts"
if [[ "$RESPONSE_STATUS" == "302 Found" ]]; then
    test_pass
else
    test_fail "$RESPONSE_STATUS"
fi

test_start "redirect_to accepts custom status"
reset_response
redirect_to "/posts" 301
if [[ "$RESPONSE_STATUS" == "301 Moved Permanently" ]]; then
    test_pass
else
    test_fail "$RESPONSE_STATUS"
fi

# Test: Flash messages
test_start "set_flash sets flash message"
reset_response
set_flash notice "Test message"
if [[ "$FLASH_NOTICE" == "Test message" ]]; then
    test_pass
else
    test_fail "$FLASH_NOTICE"
fi

test_start "set_flash sets cookie header"
reset_response
set_flash notice "Hello"
if [[ "$RESPONSE_HEADERS" == *"Set-Cookie: flash_notice="* ]]; then
    test_pass
else
    test_fail "$RESPONSE_HEADERS"
fi

# Test: Params
test_start "set_param and param work together"
set_param "title" "My Title"
result=$(param "title")
if [[ "$result" == "My Title" ]]; then
    test_pass
else
    test_fail "$result"
fi

test_start "param returns default if not set"
clear_params
result=$(param "missing" "default_value")
if [[ "$result" == "default_value" ]]; then
    test_pass
else
    test_fail "$result"
fi

test_start "parse_query_string parses params"
clear_params
parse_query_string "foo=bar&baz=qux"
if [[ $(param "foo") == "bar" ]] && [[ $(param "baz") == "qux" ]]; then
    test_pass
else
    test_fail "foo=$(param foo), baz=$(param baz)"
fi

test_start "parse_query_string handles URL encoding"
clear_params
parse_query_string "name=John+Doe&msg=Hello%20World"
if [[ $(param "name") == "John Doe" ]]; then
    test_pass
else
    test_fail "$(param name)"
fi

test_start "params_expect passes with valid params"
clear_params
set_param "title" "Test"
set_param "body" "Content"
if params_expect "title" "body"; then
    test_pass
else
    test_fail
fi

test_start "params_expect fails with missing params"
clear_params
set_param "title" "Test"
if ! params_expect "title" "body"; then
    test_pass
else
    test_fail "Should fail when body is missing"
fi

# Test: URL encode/decode
test_start "url_encode encodes special characters"
result=$(url_encode "Hello World!")
if [[ "$result" == "Hello+World%21" ]]; then
    test_pass
else
    test_fail "$result"
fi

test_start "url_decode decodes special characters"
result=$(url_decode "Hello+World%21")
if [[ "$result" == "Hello World!" ]]; then
    test_pass
else
    test_fail "$result"
fi

# Test: Controller loading
test_start "load_controller loads controller file"
if load_controller "test"; then
    test_pass
else
    test_fail "Could not load test controller"
fi

test_start "load_controller makes actions available"
if type index_action &>/dev/null; then
    test_pass
else
    test_fail "index_action not defined"
fi

test_start "load_controller fails for missing controller"
if ! load_controller "nonexistent"; then
    test_pass
else
    test_fail "Should fail for missing controller"
fi

# Test: Dispatch
test_start "dispatch_action calls the action"
reset_response
dispatch_action "test" "show"
if [[ "$RESPONSE_BODY" == *"Showing item"* ]]; then
    test_pass
else
    test_fail "$RESPONSE_BODY"
fi

test_start "dispatch_action returns 404 for missing action"
reset_response
dispatch_action "test" "nonexistent"
if [[ "$RESPONSE_STATUS" == "404 Not Found" ]]; then
    test_pass
else
    test_fail "$RESPONSE_STATUS"
fi

# Test: Before actions
test_start "before_action blocks unauthorized access"
reset_response
CURRENT_USER=""
dispatch_action "test" "protected"
if [[ "$REDIRECT_LOCATION" == "/login" ]]; then
    test_pass
else
    test_fail "Should redirect to /login"
fi

test_start "before_action allows authorized access"
reset_response
CURRENT_USER="admin"
dispatch_action "test" "protected"
if [[ "$RESPONSE_BODY" == "You have access" ]]; then
    test_pass
else
    test_fail "$RESPONSE_BODY"
fi

# Cleanup
cleanup_temp_dir

test_summary
exit $?
