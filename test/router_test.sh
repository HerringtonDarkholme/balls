#!/bin/bash
set -e
. ./test/assert.sh
. ./lib/util.sh
. ./lib/params.sh
. ./lib/router.sh

ROUTES=""
b:GET /foo home#index
b:GET /posts/:id posts#show
b:GET /files/* files#any

REQUEST_METHOD=GET
REQUEST_PATH=/posts/123
balls::route_match "$REQUEST_METHOD" "$REQUEST_PATH"
match="$ROUTE_ACTION"
echo "DEBUG match=$match" >&2
assert_eq "$match" "posts#show" "route match with param failed"
# simulate route to populate REQ_PARAMS via params::put path
for kv in $PATH_PARAMS; do
  k="${kv%%=*}"; v="${kv#*=}"
  params::put "$k" "$v"
  export REQ_PARAMS_${k}="$v"
done
echo "DEBUG id=$PATH_PARAMS_id req=$REQ_PARAMS_id arr=${PATH_PARAMS}" >&2
assert_eq "$PATH_PARAMS_id" "123" "path param not captured"
assert_eq "$REQ_PARAMS_id" "123" "path param not exported"

REQUEST_METHOD=GET
REQUEST_PATH=/files/a/b/c
balls::route_match "$REQUEST_METHOD" "$REQUEST_PATH"
match="$ROUTE_ACTION"
for kv in $PATH_PARAMS; do
  k="${kv%%=*}"; v="${kv#*=}"
  params::put "$k" "$v"
done
assert_eq "$match" "files#any" "wildcard match failed"
assert_eq "$PATH_PARAMS_splat" "a b c" "splat not captured"



pass
