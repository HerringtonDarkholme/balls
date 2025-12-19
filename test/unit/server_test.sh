#!/usr/bin/env bash
#
# Unit Tests: Server Components
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/../test_helper.sh"
source "$PROJECT_ROOT/lib/server.sh"
source "$PROJECT_ROOT/lib/controller.sh"

echo "Running Server Tests..."
echo ""

# Test: Request line parsing
test_start "parse_request_line parses GET request"
parse_request_line "GET /posts HTTP/1.1"
if [[ "$REQUEST_METHOD" == "GET" ]] && [[ "$REQUEST_PATH" == "/posts" ]]; then
    test_pass
else
    test_fail "Method: $REQUEST_METHOD, Path: $REQUEST_PATH"
fi

test_start "parse_request_line parses POST request"
parse_request_line "POST /posts HTTP/1.1"
if [[ "$REQUEST_METHOD" == "POST" ]]; then
    test_pass
else
    test_fail "$REQUEST_METHOD"
fi

test_start "parse_request_line extracts query string"
parse_request_line "GET /search?q=hello&page=1 HTTP/1.1"
if [[ "$REQUEST_PATH" == "/search" ]] && [[ "$REQUEST_QUERY" == "q=hello&page=1" ]]; then
    test_pass
else
    test_fail "Path: $REQUEST_PATH, Query: $REQUEST_QUERY"
fi

test_start "parse_request_line handles path without query"
parse_request_line "GET /about HTTP/1.1"
if [[ "$REQUEST_PATH" == "/about" ]] && [[ -z "$REQUEST_QUERY" ]]; then
    test_pass
else
    test_fail "Path: $REQUEST_PATH, Query: $REQUEST_QUERY"
fi

test_start "parse_request_line extracts HTTP version"
parse_request_line "GET / HTTP/1.0"
if [[ "$REQUEST_VERSION" == "HTTP/1.0" ]]; then
    test_pass
else
    test_fail "$REQUEST_VERSION"
fi

test_start "parse_request_line handles carriage return"
parse_request_line $'GET /test HTTP/1.1\r'
if [[ "$REQUEST_PATH" == "/test" ]]; then
    test_pass
else
    test_fail "$REQUEST_PATH"
fi

# Test: Header parsing
test_start "parse_headers extracts Content-Type"
headers="Content-Type: text/html
Content-Length: 123"
parse_headers "$headers"
if [[ "$HEADER_Content_Type" == "text/html" ]]; then
    test_pass
else
    test_fail "$HEADER_Content_Type"
fi

test_start "parse_headers extracts Content-Length"
if [[ "$CONTENT_LENGTH" == "123" ]]; then
    test_pass
else
    test_fail "$CONTENT_LENGTH"
fi

test_start "parse_headers handles multiple headers"
headers="Host: localhost:14514
User-Agent: curl/7.64.1
Accept: */*"
parse_headers "$headers"
if [[ "$HEADER_Host" == "localhost:14514" ]] && [[ "$HEADER_User_Agent" == "curl/7.64.1" ]]; then
    test_pass
else
    test_fail "Host: $HEADER_Host, User-Agent: $HEADER_User_Agent"
fi

# Test: Cookie parsing
test_start "parse_cookies extracts single cookie"
COOKIE="session=abc123"
parse_cookies
if [[ "$COOKIE_session" == "abc123" ]]; then
    test_pass
else
    test_fail "$COOKIE_session"
fi

test_start "parse_cookies extracts multiple cookies"
COOKIE="session=abc123; user_id=42; theme=dark"
parse_cookies
if [[ "$COOKIE_session" == "abc123" ]] && [[ "$COOKIE_user_id" == "42" ]] && [[ "$COOKIE_theme" == "dark" ]]; then
    test_pass
else
    test_fail "session=$COOKIE_session, user_id=$COOKIE_user_id, theme=$COOKIE_theme"
fi

# Test: Method override
test_start "check_method_override converts to PUT"
REQUEST_METHOD="POST"
REQUEST_BODY="_method=put&title=test"
check_method_override
if [[ "$REQUEST_METHOD" == "PUT" ]]; then
    test_pass
else
    test_fail "$REQUEST_METHOD"
fi

test_start "check_method_override converts to DELETE"
REQUEST_METHOD="POST"
REQUEST_BODY="title=test&_method=delete"
check_method_override
if [[ "$REQUEST_METHOD" == "DELETE" ]]; then
    test_pass
else
    test_fail "$REQUEST_METHOD"
fi

test_start "check_method_override ignores GET requests"
REQUEST_METHOD="GET"
REQUEST_BODY="_method=delete"
check_method_override
if [[ "$REQUEST_METHOD" == "GET" ]]; then
    test_pass
else
    test_fail "$REQUEST_METHOD"
fi

test_start "check_method_override handles PATCH"
REQUEST_METHOD="POST"
REQUEST_BODY="_method=PATCH"
check_method_override
if [[ "$REQUEST_METHOD" == "PATCH" ]]; then
    test_pass
else
    test_fail "$REQUEST_METHOD"
fi

# Test: Static file serving
setup_temp_dir
APP_PATH="$TEMP_DIR"
mkdir -p "$TEMP_DIR/public"

test_start "serve_static_file serves existing file"
echo "Hello World" > "$TEMP_DIR/public/test.txt"
REQUEST_PATH="/test.txt"
output=$(serve_static_file)
if [[ $? -eq 0 ]] && [[ "$output" == *"Hello World"* ]]; then
    test_pass
else
    test_fail "$output"
fi

test_start "serve_static_file returns 0 for existing file"
REQUEST_PATH="/test.txt"
serve_static_file > /dev/null
if [[ $? -eq 0 ]]; then
    test_pass
else
    test_fail "Exit code: $?"
fi

test_start "serve_static_file returns 1 for missing file"
REQUEST_PATH="/nonexistent.txt"
serve_static_file > /dev/null 2>&1
if [[ $? -eq 1 ]]; then
    test_pass
else
    test_fail "Exit code: $?"
fi

test_start "serve_static_file sets correct content type for CSS"
echo "body { color: red; }" > "$TEMP_DIR/public/style.css"
REQUEST_PATH="/style.css"
output=$(serve_static_file)
if [[ "$output" == *"text/css"* ]]; then
    test_pass
else
    test_fail "$output"
fi

test_start "serve_static_file sets correct content type for JS"
echo "console.log('hello');" > "$TEMP_DIR/public/app.js"
REQUEST_PATH="/app.js"
output=$(serve_static_file)
if [[ "$output" == *"application/javascript"* ]]; then
    test_pass
else
    test_fail "$output"
fi

# Test: Flash cookie handling
test_start "parse_flash_cookies extracts flash_notice"
COOKIE_flash_notice="Record+created"
parse_flash_cookies
if [[ "$FLASH_NOTICE" == "Record created" ]]; then
    test_pass
else
    test_fail "$FLASH_NOTICE"
fi

test_start "parse_flash_cookies extracts flash_error"
COOKIE_flash_error="Something+went+wrong"
parse_flash_cookies
if [[ "$FLASH_ERROR" == "Something went wrong" ]]; then
    test_pass
else
    test_fail "$FLASH_ERROR"
fi

# Cleanup
cleanup_temp_dir

test_summary
exit $?
