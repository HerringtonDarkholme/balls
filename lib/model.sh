#!/bin/bash

# file-backed model helpers using db.sh key/value store

[[ -z "$BALLS_DB_FILE" ]] && BALLS_DB_FILE="$BALLS_ROOT/x.db"

# Records are stored as key=value lines where key is "table:id"
# and value is a JSON-like string (or any payload). Simple and append-only.
# Storage implementation lives in lib/db.sh (db get/set/del)

model::key() {
  local table="$1"; local id="$2"
  echo "$table:$id"
}

model::get_raw() {
  local table="$1"; local id="$2"
  db get "$(model::key "$table" "$id")"
}

model::set_raw() {
  local table="$1"; local id="$2"; local payload="$3"
  db set "$(model::key "$table" "$id")" "$payload"
}

model::del_raw() {
  local table="$1"; local id="$2"
  db del "$(model::key "$table" "$id")"
}

model::next_id() {
  local table="$1"
  local seq_key="${table}:__seq"
  local current
  current=$(db get "$seq_key")
  [[ -z "$current" ]] && current=0
  local next=$((current+1))
  db set "$seq_key" "$next"
  echo "$next"
}

model::create() {
  local table="$1"; shift
  local id=$(model::next_id "$table")
  local payload="$1"
  model::set_raw "$table" "$id" "$payload"
  echo "$id"
}

model::find() {
  local table="$1"; local id="$2"
  model::get_raw "$table" "$id"
}

model::update() {
  local table="$1"; local id="$2"; local payload="$3"
  model::set_raw "$table" "$id" "$payload"
}

model::delete() {
  local table="$1"; local id="$2"
  model::del_raw "$table" "$id"
}

model::all_keys() {
  grep -E "^$1:[0-9]+=" "$BALLS_DB_FILE" 2>/dev/null | cut -d= -f1
}

model::all() {
  local table="$1"
  model::all_keys "$table" | while read key; do
    [[ -z "$key" ]] && continue
    local id="${key##*:}"
    local val="$(db get "$key")"
    echo "$id|$val"
  done
}
