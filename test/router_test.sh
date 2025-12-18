#!/bin/bash
# rudimentary router test
. ./lib/util.sh
. ./lib/params.sh
. ./lib/router.sh

ROUTES=""
b:GET /foo home#index
b:GET /posts/:id posts#show

REQUEST_METHOD=GET
REQUEST_PATH=/posts/123
match=$(balls::route_match "$REQUEST_METHOD" "$REQUEST_PATH")
if [[ "$match" != "posts#show" ]]; then
  echo "FAIL: expected posts#show, got $match"; exit 1
fi

echo "ok"
