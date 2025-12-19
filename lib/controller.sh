#!/usr/bin/env bash
#
# Bash on Balls - Controller Runtime
#
# Provides controller loading, action dispatch, and helpers
# Compatible with bash 3.2
#

# Response state
RESPONSE_STATUS="200 OK"
RESPONSE_HEADERS=""
RESPONSE_BODY=""
RESPONSE_SENT=false
REDIRECT_LOCATION=""

# Flash messages (stored in cookie)
FLASH_NOTICE=""
FLASH_ERROR=""

# Before action hooks
BEFORE_ACTIONS=""

# Request params (populated by server/param parser)
# Using PARAM_* prefix for bash 3.2 compatibility

# Reset response state for new request
reset_response() {
    RESPONSE_STATUS="200 OK"
    RESPONSE_HEADERS=""
    RESPONSE_BODY=""
    RESPONSE_SENT=false
    REDIRECT_LOCATION=""
}

# Set response status
# Usage: status 404 "Not Found"
status() {
    RESPONSE_STATUS="$1 $2"
}

# Add response header
# Usage: header "Content-Type" "text/html"
header() {
    local name="$1"
    local value="$2"
    RESPONSE_HEADERS="${RESPONSE_HEADERS}${name}: ${value}\r\n"
}

# Set flash message (for next request)
# Usage: set_flash "notice" "Record created successfully"
set_flash() {
    local type="$1"
    local message="$2"
    
    case "$type" in
        notice) FLASH_NOTICE="$message" ;;
        error)  FLASH_ERROR="$message" ;;
        *)      FLASH_NOTICE="$message" ;;
    esac
    
    # URL encode the message for cookie
    local encoded=$(url_encode "$message")
    header "Set-Cookie" "flash_${type}=${encoded}; Path=/; HttpOnly"
}

# Get flash message (clears after reading)
# Usage: flash_message="$(get_flash notice)"
get_flash() {
    local type="$1"
    local value=""
    
    case "$type" in
        notice) value="$FLASH_NOTICE"; FLASH_NOTICE="" ;;
        error)  value="$FLASH_ERROR"; FLASH_ERROR="" ;;
    esac
    
    echo "$value"
}

# Redirect to another URL
# Usage: redirect_to "/posts"
# Usage: redirect_to "/posts" 301
redirect_to() {
    local url="$1"
    local code="${2:-302}"
    
    case "$code" in
        301) RESPONSE_STATUS="301 Moved Permanently" ;;
        302) RESPONSE_STATUS="302 Found" ;;
        303) RESPONSE_STATUS="303 See Other" ;;
        307) RESPONSE_STATUS="307 Temporary Redirect" ;;
        *)   RESPONSE_STATUS="302 Found" ;;
    esac
    
    REDIRECT_LOCATION="$url"
    header "Location" "$url"
    RESPONSE_BODY=""
    RESPONSE_SENT=true
}

# Render a view template
# Usage: render "posts/index"
# Usage: render "posts/show" layout="admin"
render() {
    local template="$1"
    shift
    local layout="application"
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            layout=*) layout="${1#layout=}" ;;
            status=*) 
                local s="${1#status=}"
                case "$s" in
                    200) RESPONSE_STATUS="200 OK" ;;
                    201) RESPONSE_STATUS="201 Created" ;;
                    400) RESPONSE_STATUS="400 Bad Request" ;;
                    401) RESPONSE_STATUS="401 Unauthorized" ;;
                    403) RESPONSE_STATUS="403 Forbidden" ;;
                    404) RESPONSE_STATUS="404 Not Found" ;;
                    422) RESPONSE_STATUS="422 Unprocessable Entity" ;;
                    500) RESPONSE_STATUS="500 Internal Server Error" ;;
                    *) RESPONSE_STATUS="$s" ;;
                esac
                ;;
        esac
        shift
    done
    
    # Call view renderer (defined in lib/view.sh)
    if type render_view &>/dev/null; then
        RESPONSE_BODY=$(render_view "$template" "$layout")
    else
        RESPONSE_BODY="View renderer not loaded"
    fi
    
    header "Content-Type" "text/html; charset=utf-8"
    RESPONSE_SENT=true
}

# Render plain text
# Usage: render_text "Hello World"
render_text() {
    RESPONSE_BODY="$1"
    header "Content-Type" "text/plain; charset=utf-8"
    RESPONSE_SENT=true
}

# Render JSON
# Usage: render_json '{"status": "ok"}'
render_json() {
    RESPONSE_BODY="$1"
    header "Content-Type" "application/json; charset=utf-8"
    RESPONSE_SENT=true
}

# Render HTML directly
# Usage: render_html "<h1>Hello</h1>"
render_html() {
    RESPONSE_BODY="$1"
    header "Content-Type" "text/html; charset=utf-8"
    RESPONSE_SENT=true
}

# Register a before_action hook
# Usage: before_action "authenticate"
# Usage: before_action "load_post" only="show,edit,update,destroy"
before_action() {
    local callback="$1"
    shift
    local only=""
    local except=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            only=*) only="${1#only=}" ;;
            except=*) except="${1#except=}" ;;
        esac
        shift
    done
    
    BEFORE_ACTIONS="${BEFORE_ACTIONS}${callback}|${only}|${except};"
}

# Run before_action hooks
# Returns 1 if any hook fails (halts chain)
run_before_actions() {
    local action="$1"
    
    local tmp="$BEFORE_ACTIONS"
    while [[ "$tmp" == *";"* ]]; do
        local entry="${tmp%%;*}"
        tmp="${tmp#*;}"
        
        if [[ -z "$entry" ]]; then
            continue
        fi
        
        local callback="${entry%%|*}"
        local rest="${entry#*|}"
        local only="${rest%%|*}"
        local except="${rest#*|}"
        
        # Check if action should run this hook
        local should_run=true
        
        if [[ -n "$only" ]]; then
            should_run=false
            # Check if action is in only list
            local check=",$only,"
            if [[ "$check" == *",$action,"* ]]; then
                should_run=true
            fi
        fi
        
        if [[ -n "$except" ]]; then
            # Check if action is in except list
            local check=",$except,"
            if [[ "$check" == *",$action,"* ]]; then
                should_run=false
            fi
        fi
        
        if $should_run; then
            # Call the hook function
            if type "$callback" &>/dev/null; then
                "$callback"
                if [[ $? -ne 0 ]] || [[ "$RESPONSE_SENT" == "true" ]]; then
                    return 1
                fi
            fi
        fi
    done
    
    return 0
}

# Check if required params exist
# Usage: params_expect "title" "body"
# Returns 1 if any param is missing
params_expect() {
    local missing=()
    
    for param in "$@"; do
        local var_name="PARAM_${param}"
        eval "local value=\"\${$var_name}\""
        if [[ -z "$value" ]]; then
            missing+=("$param")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        set_flash error "Missing required parameters: ${missing[*]}"
        return 1
    fi
    
    return 0
}

# Get a param value
# Usage: title=$(param "title")
param() {
    local name="$1"
    local default="$2"
    local var_name="PARAM_${name}"
    eval "local value=\"\${$var_name}\""
    echo "${value:-$default}"
}

# Set a param value (used by parsers)
# Usage: set_param "title" "Hello World"
set_param() {
    local name="$1"
    local value="$2"
    eval "export PARAM_${name}=\"\$value\""
}

# Clear all params
clear_params() {
    # Unset all PARAM_* variables
    for var in $(compgen -v | grep '^PARAM_'); do
        unset "$var"
    done
}

# Parse query string into params
# Usage: parse_query_string "foo=bar&baz=qux"
parse_query_string() {
    local query="$1"
    
    # Split by &
    while [[ -n "$query" ]]; do
        local pair
        if [[ "$query" == *"&"* ]]; then
            pair="${query%%&*}"
            query="${query#*&}"
        else
            pair="$query"
            query=""
        fi
        
        if [[ -n "$pair" ]]; then
            local key="${pair%%=*}"
            local value="${pair#*=}"
            # URL decode
            value=$(url_decode "$value")
            set_param "$key" "$value"
        fi
    done
}

# Parse form body (application/x-www-form-urlencoded)
# Usage: parse_form_body "title=Hello&body=World"
parse_form_body() {
    parse_query_string "$1"
}

# URL encode a string
url_encode() {
    local string="$1"
    local encoded=""
    local i
    
    for ((i=0; i<${#string}; i++)); do
        local char="${string:$i:1}"
        case "$char" in
            [a-zA-Z0-9.~_-]) encoded+="$char" ;;
            ' ') encoded+='+' ;;
            *) encoded+=$(printf '%%%02X' "'$char") ;;
        esac
    done
    
    echo "$encoded"
}

# URL decode a string
url_decode() {
    local string="$1"
    # Replace + with space
    string="${string//+/ }"
    # Decode percent-encoded characters
    printf '%b' "${string//%/\\x}"
}

# Load a controller file
# Usage: load_controller "posts"
load_controller() {
    local name="$1"
    local controller_file="${APP_PATH}/app/controllers/${name}_controller.sh"
    
    if [[ -f "$controller_file" ]]; then
        source "$controller_file"
        return 0
    else
        return 1
    fi
}

# Dispatch to controller action
# Usage: dispatch_action "posts" "show"
dispatch_action() {
    local controller="$1"
    local action="$2"
    
    # Reset response state
    reset_response
    
    # Clear before actions for this controller
    BEFORE_ACTIONS=""
    
    # Load the controller
    if ! load_controller "$controller"; then
        status 500 "Internal Server Error"
        render_html "<h1>500 Internal Server Error</h1><p>Controller not found: ${controller}</p>"
        return 1
    fi
    
    # Check if action exists
    local action_func="${action}_action"
    if ! type "$action_func" &>/dev/null; then
        status 404 "Not Found"
        render_html "<h1>404 Not Found</h1><p>Action not found: ${controller}#${action}</p>"
        return 1
    fi
    
    # Run before actions
    if ! run_before_actions "$action"; then
        # Before action halted the chain (redirect or render already called)
        return 0
    fi
    
    # Call the action
    "$action_func"
    
    # If action didn't render, auto-render the default template
    if [[ "$RESPONSE_SENT" != "true" ]]; then
        render "${controller}/${action}"
    fi
    
    return 0
}

# Build the full HTTP response
build_response() {
    local response=""
    
    response="HTTP/1.1 ${RESPONSE_STATUS}\r\n"
    response+="${RESPONSE_HEADERS}"
    response+="Content-Length: ${#RESPONSE_BODY}\r\n"
    response+="Connection: close\r\n"
    response+="\r\n"
    response+="${RESPONSE_BODY}"
    
    printf '%b' "$response"
}
