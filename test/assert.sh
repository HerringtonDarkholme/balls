#!/bin/bash

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "ok"; }

assert_eq() {
  local a="$1"; local b="$2"; local msg="$3"
  [[ "$a" == "$b" ]] || fail "${msg:-expected '$b' got '$a'}"
}

assert_match() {
  local val="$1"; local pattern="$2"; local msg="$3"
  [[ "$val" =~ $pattern ]] || fail "${msg:-expected '$val' to match $pattern}"
}
