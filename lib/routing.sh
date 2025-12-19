#!/usr/bin/env bash
#
# Bash on Balls - Routing DSL
#
# Provides Rails-like routing: get, post, put, patch, delete, resources
# Compatible with bash 3.2 (no associative arrays)
#

# Route storage - using indexed arrays for bash 3.2 compatibility
# Format: "METHOD|PATH|CONTROLLER#ACTION|PATTERN"
ROUTES=()
ROUTE_COUNT=0

# Clear all routes
clear_routes() {
    ROUTES=()
    ROUTE_COUNT=0
}

# Add a route
# Usage: add_route METHOD PATH CONTROLLER#ACTION
add_route() {
    local method="$1"
    local path="$2"
    local target="$3"
    
    # Convert path to regex pattern for matching
    # Replace :param with capture group
    # Note: BSD sed uses -E for extended regex
    local pattern="$path"
    pattern=$(printf '%s' "$pattern" | /usr/bin/sed -E 's/:[a-zA-Z_][a-zA-Z0-9_]*/([^\/]+)/g')
    pattern="^${pattern}$"
    
    # Extract param names from path
    local params=""
    local tmp_path="$path"
    while [[ "$tmp_path" =~ /:([a-zA-Z_][a-zA-Z0-9_]*) ]]; do
        local param_name="${BASH_REMATCH[1]}"
        params="${params}${params:+,}${param_name}"
        tmp_path="${tmp_path#*:$param_name}"
    done
    
    ROUTES+=("${method}|${path}|${target}|${pattern}|${params}")
    ((ROUTE_COUNT++)) || true
}

# HTTP verb functions
get() {
    add_route "GET" "$1" "$2"
}

post() {
    add_route "POST" "$1" "$2"
}

put() {
    add_route "PUT" "$1" "$2"
}

patch() {
    add_route "PATCH" "$1" "$2"
}

delete() {
    add_route "DELETE" "$1" "$2"
}

# Resources macro - generates RESTful routes
# Usage: resources "posts"
# Generates:
#   GET    /posts           posts#index
#   GET    /posts/new       posts#new
#   POST   /posts           posts#create
#   GET    /posts/:id       posts#show
#   GET    /posts/:id/edit  posts#edit
#   PUT    /posts/:id       posts#update
#   PATCH  /posts/:id       posts#update
#   DELETE /posts/:id       posts#destroy
resources() {
    local name="$1"
    local controller="${2:-$name}"
    
    get "/${name}" "${controller}#index"
    get "/${name}/new" "${controller}#new"
    post "/${name}" "${controller}#create"
    get "/${name}/:id" "${controller}#show"
    get "/${name}/:id/edit" "${controller}#edit"
    put "/${name}/:id" "${controller}#update"
    patch "/${name}/:id" "${controller}#update"
    delete "/${name}/:id" "${controller}#destroy"
}

# Resource (singular) macro - for singleton resources
# Usage: resource "profile"
resource() {
    local name="$1"
    local controller="${2:-$name}"
    
    get "/${name}" "${controller}#show"
    get "/${name}/new" "${controller}#new"
    post "/${name}" "${controller}#create"
    get "/${name}/edit" "${controller}#edit"
    put "/${name}" "${controller}#update"
    patch "/${name}" "${controller}#update"
    delete "/${name}" "${controller}#destroy"
}

# Root route helper
root() {
    get "/" "$1"
}

# Match a request to a route
# Usage: match_route METHOD PATH
# Sets: MATCHED_CONTROLLER, MATCHED_ACTION, and param variables (id, etc.)
match_route() {
    local request_method="$1"
    local request_path="$2"
    
    # Remove trailing slash for matching (except root)
    if [[ "$request_path" != "/" && "$request_path" == */ ]]; then
        request_path="${request_path%/}"
    fi
    
    # Remove query string
    request_path="${request_path%%\?*}"
    
    MATCHED_CONTROLLER=""
    MATCHED_ACTION=""
    MATCHED_ROUTE=""
    
    for route in "${ROUTES[@]}"; do
        IFS='|' read -r method path target pattern params <<< "$route"
        
        # Check method
        if [[ "$method" != "$request_method" ]]; then
            continue
        fi
        
        # Try to match path
        # For simple paths without params
        if [[ "$path" == "$request_path" ]]; then
            IFS='#' read -r MATCHED_CONTROLLER MATCHED_ACTION <<< "$target"
            MATCHED_ROUTE="$path"
            return 0
        fi
        
        # For paths with parameters, use pattern matching
        if [[ "$path" == *":"* ]]; then
            # Split paths by / - remove leading slash first
            local path_trimmed="${path#/}"
            local req_trimmed="${request_path#/}"
            
            # Split path template into parts
            local path_parts=""
            local path_count=0
            local tmp="$path_trimmed"
            while [[ "$tmp" == */* ]]; do
                eval "local path_part_${path_count}=\"\${tmp%%/*}\""
                tmp="${tmp#*/}"
                ((path_count++))
            done
            [[ -n "$tmp" ]] && { eval "local path_part_${path_count}=\"\$tmp\""; ((path_count++)); }
            
            # Split request path into parts
            local req_count=0
            tmp="$req_trimmed"
            while [[ "$tmp" == */* ]]; do
                eval "local req_part_${req_count}=\"\${tmp%%/*}\""
                tmp="${tmp#*/}"
                ((req_count++))
            done
            [[ -n "$tmp" ]] && { eval "local req_part_${req_count}=\"\$tmp\""; ((req_count++)); }
            
            # Check if they have same number of parts
            if [[ $path_count -ne $req_count ]]; then
                continue
            fi
            
            local matched=true
            local extracted_params=""
            
            local i=0
            while [[ $i -lt $path_count ]]; do
                eval "local path_part=\"\$path_part_${i}\""
                eval "local request_part=\"\$req_part_${i}\""
                
                if [[ "$path_part" == :* ]]; then
                    # This is a parameter - extract it
                    local param_name="${path_part#:}"
                    extracted_params="${extracted_params}${param_name}=${request_part};"
                elif [[ "$path_part" != "$request_part" ]]; then
                    matched=false
                    break
                fi
                i=$((i + 1))
            done
            
            if $matched; then
                IFS='#' read -r MATCHED_CONTROLLER MATCHED_ACTION <<< "$target"
                MATCHED_ROUTE="$path"
                
                # Set parameter variables from extracted_params (format: name=value;name2=value2;)
                while [[ "$extracted_params" == *";"* ]]; do
                    local param_pair="${extracted_params%%;*}"
                    extracted_params="${extracted_params#*;}"
                    if [[ -n "$param_pair" ]]; then
                        local pname="${param_pair%%=*}"
                        local pvalue="${param_pair#*=}"
                        eval "export ROUTE_PARAM_${pname}=\"\$pvalue\""
                        eval "export ${pname}=\"\$pvalue\""
                    fi
                done
                
                return 0
            fi
        fi
    done
    
    return 1
}

# Print route table
print_routes() {
    printf "%-8s %-30s %s\n" "Method" "Path" "Controller#Action"
    printf "%-8s %-30s %s\n" "------" "----" "-----------------"
    
    for route in "${ROUTES[@]}"; do
        IFS='|' read -r method path target pattern params <<< "$route"
        printf "%-8s %-30s %s\n" "$method" "$path" "$target"
    done
}

# Get route count
route_count() {
    echo "${#ROUTES[@]}"
}

# Check if a route exists
route_exists() {
    local method="$1"
    local path="$2"
    
    for route in "${ROUTES[@]}"; do
        IFS='|' read -r r_method r_path r_target r_pattern r_params <<< "$route"
        if [[ "$r_method" == "$method" && "$r_path" == "$path" ]]; then
            return 0
        fi
    done
    return 1
}
