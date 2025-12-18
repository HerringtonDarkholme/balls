#!/bin/bash

# shql-backed model helpers (SQLite via shql)

BALLS_SHQL=${BALLS_SHQL:-shql}
[[ -z "$BALLS_DB_DIR" ]] && BALLS_DB_DIR="$BALLS_ROOT/db"
[[ -z "$BALLS_DB_FILE" ]] && BALLS_DB_FILE="$BALLS_DB_DIR/${BALLS_ENV:-development}.sqlite"

model::db() {
  echo "$BALLS_DB_FILE"
}

model::exec() {
  local sql="$1"; shift
  local db="$(model::db)"
  $BALLS_SHQL "$db" "$sql" "$@"
}

model::find() {
  local table="$1"; local id="$2"
  model::exec "SELECT * FROM $table WHERE id = ? LIMIT 1;" "$id"
}

model::where() {
  local table="$1"; shift
  local clause="$1"; shift
  model::exec "SELECT * FROM $table WHERE $clause;" "$@"
}

model::insert() {
  local table="$1"; shift
  local fields=()
  local placeholders=()
  local values=()
  while [[ $# -gt 0 ]]; do
    fields+=("$1"); shift
    placeholders+=("?")
    values+=("$1"); shift
  done
  local sql="INSERT INTO $table (${fields[*]// /,}) VALUES (${placeholders[*]// /,});"
  model::exec "$sql" "${values[@]}"
}

model::update() {
  local table="$1"; shift
  local id="$1"; shift
  local sets=()
  local values=()
  while [[ $# -gt 0 ]]; do
    sets+=("$1 = ?"); shift
    values+=("$1"); shift
  done
  values+=("$id")
  local sql="UPDATE $table SET ${sets[*]// /,} WHERE id = ?;"
  model::exec "$sql" "${values[@]}"
}

model::delete() {
  local table="$1"; local id="$2"
  model::exec "DELETE FROM $table WHERE id = ?;" "$id"
}

model::ensure_schema_migrations() {
  model::exec "CREATE TABLE IF NOT EXISTS schema_migrations (version TEXT PRIMARY KEY);"
}

model::migrate() {
  model::ensure_schema_migrations
  local db="$(model::db)"
  for migration in $(ls "$BALLS_DB_DIR"/migrate/*.sh 2>/dev/null | sort); do
    local version=$(basename "$migration" .sh)
    if ! model::exec "SELECT version FROM schema_migrations WHERE version = ?;" "$version" | grep -q "$version"; then
      BALLS_DB_FILE="$db" bash "$migration"
      model::exec "INSERT INTO schema_migrations (version) VALUES (?);" "$version"
    fi
  done
}
