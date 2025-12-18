#!/bin/bash

http::parse_request() {
  http::read req_line
  req_line=($req_line)
  export REQUEST_METHOD=${req_line[0]}
  export REQUEST_URI=${req_line[1]}
  export REQUEST_PATH=${REQUEST_URI%%\?*}
  export QUERY_STRING=${REQUEST_URI#*\?}
  [[ "$REQUEST_URI" == "$REQUEST_PATH" ]] && QUERY_STRING=""
  export HTTP_VERSION=${req_line[2]}
  export SERVER_SOFTWARE="balls/0.0"

  declare -gA HEADERS
  local key val
  while http::read HEADER_LINE; do
    key="${HEADER_LINE%%*( ):*}"; trim key
    val="${HEADER_LINE#*:*( )}"; trim val
    HEADERS["$key"]="$val"
  done
}

http::read() {
  local __var=$1; shift
  IFS= read __in
  local RETVAL=$?
  __in=$(echo "$__in" | tr -d '\r')
  export "$__var"="$__in"
  [ "$RETVAL" = 0 ] && [ -n "${!__var}" ]
}

declare -a HTTP_STATUSES
HTTP_STATUSES[200]='OK'
HTTP_STATUSES[404]='Not Found'
HTTP_STATUSES[500]='Internal Server Error'

http::status() {
  local code=$1; shift
  local message=$1; shift
  [ -z "$message" ] && message=${HTTP_STATUSES[$code]}
  http::header_echo "$HTTP_VERSION $code $message"
}

http::header() { http::header_echo "$1: $2"; }
http::header_echo() { echo "$@" >&3; }
http::content_length() { http::header 'Content-Length' "$1"; }
http::content_type() { http::header 'Content-Type' "$@"; }
