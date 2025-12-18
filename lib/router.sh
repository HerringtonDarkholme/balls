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
PATH_PARAMS=""
PATH_PARAMS_id=""
PATH_PARAMS_splat=""
PATH_PARAMS_keys=""

balls::path_param_put() {
  local key="$1"; local val="$2"
  PATH_PARAMS="$PATH_PARAMS $key=$val"
  PATH_PARAMS_keys="$PATH_PARAMS_keys $key"
  export PATH_PARAMS_${key}="$val"
}

balls::path_match() {
  local pattern="$1"; local path="$2"
  PATH_PARAMS=""; PATH_PARAMS_keys=""; PATH_PARAMS_id=""; PATH_PARAMS_splat=""
  local p="${pattern#/}"; local a="${path#/}"
  IFS='/' read -r -a pseg <<< "$p"
  IFS='/' read -r -a aseg <<< "$a"
  [[ -z "$p" ]] && pseg=()
  [[ -z "$a" ]] && aseg=()
  local pi=${#pseg[@]} ai=${#aseg[@]}
  local wildcard=0
  for seg in "${pseg[@]}"; do [[ "$seg" == "*" ]] && wildcard=1; done
  if [[ $wildcard -eq 0 && $pi -ne $ai ]]; then return 1; fi
  local i
  for i in "${!pseg[@]}"; do
    local ps="${pseg[$i]}"
    local as="${aseg[$i]}"
    if [[ -z "$ps" && -z "$as" ]]; then continue; fi
    if [[ "$ps" == "*" ]]; then
      balls::path_param_put "splat" "${aseg[*]:$i}"
      return 0
    elif [[ "$ps" == :* ]]; then
      local name="${ps#:}"
      balls::path_param_put "$name" "$as"
    else
      [[ "$ps" == "$as" ]] || return 1
    fi
  done
  return 0
}

balls::route_match() {
  local method="$1"; local path="$2"
  ROUTE_ACTION=""
  PATH_PARAMS=""; PATH_PARAMS_keys=""; PATH_PARAMS_id=""; PATH_PARAMS_splat=""
  while IFS=$'\t' read -r m p a; do
    [[ "$m" != "$method" ]] && continue
    if balls::path_match "$p" "$path"; then ROUTE_ACTION="$a"; break; fi
  done <<< "$(printf "%s" "$ROUTES")"
  echo -n "$ROUTE_ACTION"
}

balls::route() {
  [[ "$BALLS_RELOAD" = 1 ]] && balls::load_app
  [[ "$REQUEST_METHOD" = "HEAD" ]] && body_sock=/dev/null

  balls::route_match "$REQUEST_METHOD" "$REQUEST_PATH"
  local action="$ROUTE_ACTION"

  if [ -n "$action" ] && exists "$action"; then
    for kv in $PATH_PARAMS; do
      k="${kv%%=*}"; v="${kv#*=}"
      params::put "$k" "$v"
      export REQ_PARAMS_${k}="$v"
    done
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
