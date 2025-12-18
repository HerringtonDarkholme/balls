#!/bin/bash
set -e
for t in test/*_test.sh; do
  [ -x "$t" ] || chmod +x "$t"
  "$t"
done
