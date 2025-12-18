#!/bin/bash

# Simple params parsing (query + form-encoded body)

params::reset() {
  unset REQ_PARAMS_KEYS REQ_PARAMS
  REQ_PARAMS_KEYS=()
  REQ_PARAMS=()
}

params::put() {
  local key="$1"; shift
  local val="$1"
  REQ_PARAMS_KEYS+=("$key")
  REQ_PARAMS+=("$key=$val")
  export "REQ_PARAMS_${key}"="$val"
}

params::urldecode() {
  local data=${1//+/ }
  printf '%b' "${data//%/\\x}"
}

params::parse_kv_string() {
  local input="$1"
  IFS='&' read -ra pairs <<< "$input"
  for pair in "${pairs[@]}"; do
    [[ -z "$pair" ]] && continue
    IFS='=' read -r k v <<< "$pair"
    k=$(params::urldecode "$k")
    v=$(params::urldecode "$v")
    params::put "$k" "$v"
  done
}

params::parse_query() {
  local qs="$1"
  [[ -z "$qs" || "$qs" == "$REQUEST_URI" ]] && return
  params::parse_kv_string "$qs"
}

params::parse_body() {
  local body="$1"
  local ctype="$2"
  [[ -z "$body" ]] && return
  if [[ "$ctype" == application/x-www-form-urlencoded* ]]; then
    params::parse_kv_string "$body"
  elif [[ "$ctype" == application/json* ]]; then
    if command -v jq >/dev/null 2>&1; then
      # flat object only
      local keys
      keys=$(printf '%s' "$body" | jq -r 'keys[]' 2>/dev/null)
      while IFS= read -r k; do
        [[ -z "$k" ]] && continue
        local v
        v=$(printf '%s' "$body" | jq -r --arg k "$k" '.[$k]' 2>/dev/null)
        params::put "$k" "$v"
      done <<< "$keys"
    fi
  fi
}
