#!/usr/bin/env bash
#
# Unit Tests: Routing DSL
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/../test_helper.sh"
source "$PROJECT_ROOT/lib/routing.sh"

echo "Running Routing Tests..."
echo ""

# Test: HTTP verb functions exist
test_start "get function exists"
if type get &>/dev/null; then
    test_pass
else
    test_fail
fi

test_start "post function exists"
if type post &>/dev/null; then
    test_pass
else
    test_fail
fi

test_start "put function exists"
if type put &>/dev/null; then
    test_pass
else
    test_fail
fi

test_start "patch function exists"
if type patch &>/dev/null; then
    test_pass
else
    test_fail
fi

test_start "delete function exists"
if type delete &>/dev/null; then
    test_pass
else
    test_fail
fi

# Test: Route registration
clear_routes
test_start "get registers a route"
get "/test" "test#index"
if [[ $(route_count) -eq 1 ]]; then
    test_pass
else
    test_fail "Expected 1 route, got $(route_count)"
fi

clear_routes
test_start "multiple routes can be registered"
get "/" "home#index"
get "/about" "pages#about"
post "/contact" "pages#contact"
if [[ $(route_count) -eq 3 ]]; then
    test_pass
else
    test_fail "Expected 3 routes, got $(route_count)"
fi

# Test: Resources macro
clear_routes
test_start "resources generates 8 routes"
resources posts
count=$(route_count)
if [[ $count -eq 8 ]]; then
    test_pass
else
    test_fail "Expected 8 routes, got $count"
fi

test_start "resources creates index route"
if route_exists "GET" "/posts"; then
    test_pass
else
    test_fail
fi

test_start "resources creates new route"
if route_exists "GET" "/posts/new"; then
    test_pass
else
    test_fail
fi

test_start "resources creates create route"
if route_exists "POST" "/posts"; then
    test_pass
else
    test_fail
fi

test_start "resources creates show route"
if route_exists "GET" "/posts/:id"; then
    test_pass
else
    test_fail
fi

test_start "resources creates edit route"
if route_exists "GET" "/posts/:id/edit"; then
    test_pass
else
    test_fail
fi

test_start "resources creates update route (PUT)"
if route_exists "PUT" "/posts/:id"; then
    test_pass
else
    test_fail
fi

test_start "resources creates update route (PATCH)"
if route_exists "PATCH" "/posts/:id"; then
    test_pass
else
    test_fail
fi

test_start "resources creates destroy route"
if route_exists "DELETE" "/posts/:id"; then
    test_pass
else
    test_fail
fi

# Test: Route matching - simple paths
clear_routes
get "/" "home#index"
get "/about" "pages#about"
post "/contact" "pages#submit"

test_start "matches exact path GET /"
if match_route "GET" "/" && [[ "$MATCHED_CONTROLLER" == "home" ]] && [[ "$MATCHED_ACTION" == "index" ]]; then
    test_pass
else
    test_fail "Got $MATCHED_CONTROLLER#$MATCHED_ACTION"
fi

test_start "matches exact path GET /about"
if match_route "GET" "/about" && [[ "$MATCHED_CONTROLLER" == "pages" ]] && [[ "$MATCHED_ACTION" == "about" ]]; then
    test_pass
else
    test_fail "Got $MATCHED_CONTROLLER#$MATCHED_ACTION"
fi

test_start "matches method POST /contact"
if match_route "POST" "/contact" && [[ "$MATCHED_CONTROLLER" == "pages" ]] && [[ "$MATCHED_ACTION" == "submit" ]]; then
    test_pass
else
    test_fail "Got $MATCHED_CONTROLLER#$MATCHED_ACTION"
fi

test_start "fails for wrong method"
if ! match_route "GET" "/contact"; then
    test_pass
else
    test_fail "Should not match GET /contact"
fi

test_start "fails for unknown path"
if ! match_route "GET" "/unknown"; then
    test_pass
else
    test_fail "Should not match /unknown"
fi

# Test: Route matching with parameters
clear_routes
resources posts

test_start "matches /posts/:id and extracts id"
if match_route "GET" "/posts/123" && [[ "$id" == "123" ]]; then
    test_pass
else
    test_fail "Got id=$id"
fi

test_start "matches /posts/:id/edit and extracts id"
if match_route "GET" "/posts/456/edit" && [[ "$id" == "456" ]]; then
    test_pass
else
    test_fail "Got id=$id"
fi

test_start "ROUTE_PARAM_id is also set"
match_route "GET" "/posts/789"
if [[ "$ROUTE_PARAM_id" == "789" ]]; then
    test_pass
else
    test_fail "Got ROUTE_PARAM_id=$ROUTE_PARAM_id"
fi

# Test: Multiple parameters
clear_routes
get "/users/:user_id/posts/:post_id" "posts#show"

test_start "extracts multiple parameters"
if match_route "GET" "/users/10/posts/20" && [[ "$user_id" == "10" ]] && [[ "$post_id" == "20" ]]; then
    test_pass
else
    test_fail "Got user_id=$user_id, post_id=$post_id"
fi

# Test: Query string handling
clear_routes
get "/search" "search#index"

test_start "matches path ignoring query string"
if match_route "GET" "/search?q=test&page=1" && [[ "$MATCHED_ACTION" == "index" ]]; then
    test_pass
else
    test_fail "Got $MATCHED_CONTROLLER#$MATCHED_ACTION"
fi

# Test: Trailing slash handling
clear_routes
get "/posts" "posts#index"

test_start "matches path with trailing slash"
if match_route "GET" "/posts/" && [[ "$MATCHED_ACTION" == "index" ]]; then
    test_pass
else
    test_fail "Got $MATCHED_CONTROLLER#$MATCHED_ACTION"
fi

# Test: Root helper
clear_routes
root "home#index"

test_start "root helper creates GET / route"
if route_exists "GET" "/" && match_route "GET" "/" && [[ "$MATCHED_ACTION" == "index" ]]; then
    test_pass
else
    test_fail
fi

# Test: print_routes function
clear_routes
get "/test" "test#index"
test_start "print_routes outputs route table"
output=$(print_routes)
if [[ "$output" == *"GET"* ]] && [[ "$output" == *"/test"* ]] && [[ "$output" == *"test#index"* ]]; then
    test_pass
else
    test_fail "Output: $output"
fi

# Print summary
test_summary
exit $?
