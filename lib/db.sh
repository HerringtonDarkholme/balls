#!/bin/bash

# Simple file-backed key/value store
# Uses BALLS_DB_FILE (default: $BALLS_DB_DIR/balls.db)

: "${BALLS_DB_FILE:=$BALLS_ROOT/x.db}"

touch "$BALLS_DB_FILE"

# db get key
# db set key value
# db del key
# keys are stored as literal strings, values stored as-is

db() {
  local op="$1"; shift
  case "$op" in
    get)
      local key="$1"
      grep -F "^$key=" "$BALLS_DB_FILE" 2>/dev/null | tail -1 | cut -d= -f2-
      ;;
    set)
      local key="$1"; shift
      local val="$1"
      echo "$key=$val" >> "$BALLS_DB_FILE"
      ;;
    del)
      local key="$1"
      # macOS-compatible sed -i
      sed -i '' "/^$key=/d" "$BALLS_DB_FILE"
      ;;
    *)
      echo "unknown db op" >&2
      return 1
      ;;
  esac
}
