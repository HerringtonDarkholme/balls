#!/bin/bash
set -e

. ./lib/view.sh

# simple context
message="hi"
rendered=$(render::process "<p>{{message}}</p>")
[[ "$rendered" == "<p>hi</p>" ]] || { echo "FAIL view interp"; exit 1; }

echo "ok"
