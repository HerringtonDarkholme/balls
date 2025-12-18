#!/bin/bash

balls::define_route() {
  local verb=$1; shift
  local path=$1; shift
  local action=$1; shift
  local route_line="$(echo -e "$verb\t$path\t$action")"
  if [ -z "$ROUTES" ]; then
    ROUTES="$route_line"
  else
    ROUTES="$ROUTES
$route_line"
  fi
}

b:GET()    { balls::define_route GET "$@"; }
b:POST()   { balls::define_route POST "$@"; }
b:PUT()    { balls::define_route PUT "$@"; }
b:DELETE() { balls::define_route DELETE "$@"; }

balls::path_match() {
  local pattern="$1"; local path="$2"
  declare -gA PATH_PARAMS
  PATH_PARAMS=()
  local p="${pattern#/}"; local a="${path#/}"
  IFS='/' read -ra pseg <<< "$p"
  IFS='/' read -ra aseg <<< "$a"
  local pi=${#pseg[@]} ai=${#aseg[@]}
  local wildcard=0
  for seg in "${pseg[@]}"; do [[ "$seg" == "*" ]] && wildcard=1; done
  if [[ $wildcard -eq 0 && $pi -ne $ai ]]; then return 1; fi
  local i
  for i in "${!pseg[@]}"; do
    local ps="${pseg[$i]}"
    local as="${aseg[$i]}"
    if [[ "$ps" == "*" ]]; then
      PATH_PARAMS["splat"]="${aseg[*]:$i}"
      return 0
    elif [[ "$ps" == :* ]]; then
      local name="${ps#:}"
      PATH_PARAMS["$name"]="$as"
    else
      [[ "$ps" == "$as" ]] || return 1
    fi
  done
  return 0
}

balls::route_match() {
  local method="$1"; local path="$2"
  local action=""
  declare -gA PATH_PARAMS
  while IFS=$'\t' read -r m p a; do
    [[ "$m" != "$method" ]] && continue
    if balls::path_match "$p" "$path"; then action="$a"; break; fi
  done <<< "$ROUTES"
  echo -n "$action"
}

balls::route() {
  [[ "$BALLS_RELOAD" = 1 ]] && balls::load_app
  [[ "$REQUEST_METHOD" = "HEAD" ]] && body_sock=/dev/null

  local action=$(balls::route_match "$REQUEST_METHOD" "$REQUEST_PATH")

  if [ -n "$action" ] && exists "$action"; then
    for k in "${!PATH_PARAMS[@]}"; do params::put "$k" "${PATH_PARAMS[$k]}"; done
    headers_sock=$BALLS_TMP/balls.headers.$(_hash).sock
    [ -p $headers_sock ] || mkfifo $headers_sock
    ( $action 3>$headers_sock ) | {
      headers=$(cat <$headers_sock)
      body=$(cat -)
      response=$(echo "$headers"; http::content_length ${#body}; echo; echo "$body")
      echo "$response"
    }
    rm -f "$headers_sock"
  else
    if [[ "$REQUEST_METHOD" = "HEAD" ]]; then
      REQUEST_METHOD=GET; balls::route
    else
      http::status 404 3>&1; http::content_type text/plain 3>&1; echo; echo "No route matched $REQUEST_METHOD $REQUEST_PATH"; echo
    fi
  fi
}
