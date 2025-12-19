#!/usr/bin/env bash
#
# Bash on Balls - HTTP Server
#
# BSD nc-based HTTP server with request parsing and routing
# Compatible with macOS (BSD nc lacks -k flag)
#

# Server configuration
SERVER_PORT="${PORT:-3000}"
SERVER_HOST="${HOST:-127.0.0.1}"

# Source dependencies
BALLS_LIB="${BALLS_ROOT:-$(dirname "${BASH_SOURCE[0]}")/../}/lib"

# Request state
REQUEST_METHOD=""
REQUEST_PATH=""
REQUEST_QUERY=""
REQUEST_VERSION=""
REQUEST_HEADERS=""
REQUEST_BODY=""

# Parse HTTP request line
# Format: GET /path?query HTTP/1.1
parse_request_line() {
    local line="$1"
    
    # Remove carriage return if present
    line="${line%$'\r'}"
    
    # Split by spaces
    REQUEST_METHOD="${line%% *}"
    local rest="${line#* }"
    local path_query="${rest%% *}"
    REQUEST_VERSION="${rest##* }"
    
    # Split path and query string
    if [[ "$path_query" == *"?"* ]]; then
        REQUEST_PATH="${path_query%%\?*}"
        REQUEST_QUERY="${path_query#*\?}"
    else
        REQUEST_PATH="$path_query"
        REQUEST_QUERY=""
    fi
}

# Parse HTTP headers
# Sets HEADER_* variables
parse_headers() {
    local headers="$1"
    
    while IFS= read -r line; do
        # Remove carriage return
        line="${line%$'\r'}"
        
        # Empty line marks end of headers
        [[ -z "$line" ]] && break
        
        # Parse header: Name: Value
        local name="${line%%:*}"
        local value="${line#*: }"
        
        # Normalize header name (replace - with _)
        name="${name//-/_}"
        
        # Store header
        eval "export HEADER_${name}=\"\$value\""
        
        # Store common headers in standard names too
        case "$name" in
            Content_Length) CONTENT_LENGTH="$value" ;;
            Content_Type) CONTENT_TYPE="$value" ;;
            Cookie) COOKIE="$value" ;;
            Authorization) AUTHORIZATION="$value" ;;
            Host) HOST_HEADER="$value" ;;
            HX_Request) HX_REQUEST="$value" ;;
            HX_Target) HX_TARGET="$value" ;;
            HX_Trigger) HX_TRIGGER="$value" ;;
            HX_Current_URL) HX_CURRENT_URL="$value" ;;
        esac
    done <<< "$headers"
}

# Parse cookies from Cookie header
parse_cookies() {
    local cookie_header="$COOKIE"
    
    while [[ -n "$cookie_header" ]]; do
        local cookie
        if [[ "$cookie_header" == *";"* ]]; then
            cookie="${cookie_header%%;*}"
            cookie_header="${cookie_header#*;}"
            cookie_header="${cookie_header# }"  # Trim leading space
        else
            cookie="$cookie_header"
            cookie_header=""
        fi
        
        local name="${cookie%%=*}"
        local value="${cookie#*=}"
        name="${name# }"  # Trim spaces
        name="${name% }"
        
        eval "export COOKIE_${name}=\"\$value\""
    done
}

# Parse flash messages from cookies
parse_flash_cookies() {
    # Check for flash cookies
    if [[ -n "$COOKIE_flash_notice" ]]; then
        FLASH_NOTICE=$(url_decode "$COOKIE_flash_notice")
        flash_notice="$FLASH_NOTICE"
    fi
    if [[ -n "$COOKIE_flash_error" ]]; then
        FLASH_ERROR=$(url_decode "$COOKIE_flash_error")
        flash_error="$FLASH_ERROR"
    fi
}

# Clear flash cookies (they're one-time use)
clear_flash_cookies() {
    if [[ -n "$COOKIE_flash_notice" ]]; then
        header "Set-Cookie" "flash_notice=; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT"
    fi
    if [[ -n "$COOKIE_flash_error" ]]; then
        header "Set-Cookie" "flash_error=; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT"
    fi
}

# Read request body based on Content-Length
read_body() {
    local length="${CONTENT_LENGTH:-0}"
    
    if [[ $length -gt 0 ]]; then
        # Read exactly $length bytes
        REQUEST_BODY=$(head -c "$length")
    else
        REQUEST_BODY=""
    fi
}

# Check for method override (_method parameter)
check_method_override() {
    if [[ "$REQUEST_METHOD" == "POST" && -n "$REQUEST_BODY" ]]; then
        # Check for _method in body
        local override=""
        local tmp="$REQUEST_BODY"
        
        while [[ -n "$tmp" ]]; do
            local pair
            if [[ "$tmp" == *"&"* ]]; then
                pair="${tmp%%&*}"
                tmp="${tmp#*&}"
            else
                pair="$tmp"
                tmp=""
            fi
            
            if [[ "$pair" == "_method="* ]]; then
                override="${pair#_method=}"
                override=$(echo "$override" | tr '[:lower:]' '[:upper:]')
                break
            fi
        done
        
        if [[ -n "$override" ]]; then
            case "$override" in
                PUT|PATCH|DELETE)
                    REQUEST_METHOD="$override"
                    ;;
            esac
        fi
    fi
}

# Serve static file from public directory
serve_static_file() {
    local file_path="${APP_PATH}/public${REQUEST_PATH}"
    
    if [[ -f "$file_path" ]]; then
        # Determine content type
        local content_type="application/octet-stream"
        case "$file_path" in
            *.html) content_type="text/html; charset=utf-8" ;;
            *.css)  content_type="text/css; charset=utf-8" ;;
            *.js)   content_type="application/javascript; charset=utf-8" ;;
            *.json) content_type="application/json; charset=utf-8" ;;
            *.png)  content_type="image/png" ;;
            *.jpg|*.jpeg) content_type="image/jpeg" ;;
            *.gif)  content_type="image/gif" ;;
            *.svg)  content_type="image/svg+xml" ;;
            *.ico)  content_type="image/x-icon" ;;
            *.txt)  content_type="text/plain; charset=utf-8" ;;
        esac
        
        local file_size=$(wc -c < "$file_path" | tr -d ' ')
        
        # Send response
        printf "HTTP/1.1 200 OK\r\n"
        printf "Content-Type: %s\r\n" "$content_type"
        printf "Content-Length: %s\r\n" "$file_size"
        printf "Connection: close\r\n"
        printf "\r\n"
        cat "$file_path"
        
        return 0
    fi
    
    return 1
}

# Handle a single request
handle_request() {
    # Disable errexit for request handling - many commands may return non-zero
    # legitimately (e.g., failed regex matches, empty reads)
    set +e
    
    # Read request line
    local request_line
    IFS= read -r request_line
    
    # Check for empty request
    if [[ -z "$request_line" || "$request_line" == $'\r' ]]; then
        return 1
    fi
    
    parse_request_line "$request_line"
    
    # Read headers
    local headers=""
    while IFS= read -r line; do
        line="${line%$'\r'}"
        [[ -z "$line" ]] && break
        headers+="$line"$'\n'
    done
    
    parse_headers "$headers"
    parse_cookies
    parse_flash_cookies
    
    # Read body if present
    read_body
    
    # Check for method override
    check_method_override
    
    # Log request
    log_request
    
    # Try to serve static file first
    if serve_static_file; then
        return 0
    fi
    
    # Source routing and other libs
    source "$BALLS_LIB/routing.sh"
    source "$BALLS_LIB/controller.sh"
    source "$BALLS_LIB/view.sh"
    source "$BALLS_LIB/model.sh"
    
    # Load app routes
    if [[ -f "${APP_PATH}/config/routes.sh" ]]; then
        source "${APP_PATH}/config/routes.sh"
    fi
    
    # Parse params from query string and body
    clear_params
    [[ -n "$REQUEST_QUERY" ]] && parse_query_string "$REQUEST_QUERY"
    [[ -n "$REQUEST_BODY" ]] && parse_form_body "$REQUEST_BODY"
    
    # Match route and dispatch
    if match_route "$REQUEST_METHOD" "$REQUEST_PATH"; then
        # Clear flash cookies after reading
        clear_flash_cookies
        
        dispatch_action "$MATCHED_CONTROLLER" "$MATCHED_ACTION"
    else
        # 404 Not Found
        status 404 "Not Found"
        RESPONSE_BODY="<h1>404 Not Found</h1><p>The requested URL was not found.</p>"
        header "Content-Type" "text/html; charset=utf-8"
    fi
    
    # Send response
    printf "HTTP/1.1 %s\r\n" "$RESPONSE_STATUS"
    printf "%b" "$RESPONSE_HEADERS"
    printf "Content-Length: %d\r\n" "${#RESPONSE_BODY}"
    printf "Connection: close\r\n"
    printf "\r\n"
    printf "%s" "$RESPONSE_BODY"
}

# Log request to stdout and file
log_request() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_line="[$timestamp] $REQUEST_METHOD $REQUEST_PATH"
    
    # Log to stdout
    echo "$log_line" >&2
    
    # Log to file if configured
    if [[ -n "$LOG_FILE" ]]; then
        echo "$log_line" >> "${APP_PATH}/${LOG_FILE}"
    fi
}

# Main server loop using BSD nc
# BSD nc doesn't support -k (keep-alive), so we loop
# Uses FIFOs with read/write mode to prevent deadlocks
start_server() {
    local port="${1:-$SERVER_PORT}"
    
    trap 'echo ""; echo "Server stopped"; exit 0' INT TERM
    
    echo "Server ready on http://${SERVER_HOST}:${port}"
    echo ""
    
    while true; do
        # Create pipes for this connection
        local pipe_dir=$(mktemp -d)
        local input_pipe="$pipe_dir/input"
        local output_pipe="$pipe_dir/output"
        mkfifo "$input_pipe" "$output_pipe"
        
        # Open both pipes for read/write to prevent blocking
        # This is the key to making FIFOs work with BSD nc
        exec 3<>"$input_pipe"   # Request pipe (nc writes, handler reads)
        exec 4<>"$output_pipe"  # Response pipe (handler writes, nc reads)
        
        # Start handler in background
        # Reads from fd 3 (request), writes to fd 4 (response)
        # IMPORTANT: The output redirection (>&4) must be OUTSIDE the braces
        # to work correctly with the subshell
        {
            handle_request <&3
        } >&4 &
        local handler_pid=$!
        
        # nc: reads from client, writes to fd 3 (request)
        #     reads from fd 4 (response), writes to client
        nc -l "$port" <&4 >&3 2>/dev/null
        
        # Close file descriptors
        exec 3>&-
        exec 4>&-
        
        # Wait for handler to complete
        wait $handler_pid 2>/dev/null || true
        
        # Cleanup
        rm -rf "$pipe_dir"
        
        sleep 0.01
    done
}
