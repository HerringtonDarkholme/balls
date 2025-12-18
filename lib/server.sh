#!/bin/bash

_hash() { echo $$.$(date +'%s.%N').$RANDOM; }

balls::load_app() {
  ROUTES=""
  [ -f "$BALLS_ROOT/config/routes.sh" ] && . "$BALLS_ROOT/config/routes.sh"
  for controller in "$BALLS_ACTIONS"/*.sh; do
    [ -f "$controller" ] && . "$controller"
  done
}

balls::serve_file() {
  local path="$1"
  if [ -f "$BALLS_PUBLIC/$path" ]; then
    http::status 200 3>&1
    http::content_type "$(file -I "$BALLS_PUBLIC/$path" | cut -d: -f2 | awk '{print $1}')" 3>&1
    echo >&3
    cat "$BALLS_PUBLIC/$path"
    return 0
  fi
  return 1
}

balls::handle_request() {
  http::parse_request
  local clean_path=${REQUEST_PATH#/}
  if balls::serve_file "$clean_path"; then
    return
  fi
  balls::route
}

balls::server() {
  balls::load_app
  http_sock=$BALLS_TMP/balls.http.$$.sock
  [ -p $http_sock ] || mkfifo $http_sock
  while true; do
    cat $http_sock | nc -l -p $BALLS_PORT | (
      http::parse_request
      balls::route > $http_sock
    )
  done
}

cleanup() { rm -f "$headers_sock" "$http_sock"; }
trap 'cleanup; exit' INT

balls::server
