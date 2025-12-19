#!/usr/bin/env bash
#
# Post Model
#

MODEL_NAME="posts"
MODEL_FIELDS=("id" "title" "body")

# Validations
validate_post() {
    local errors=""
    [[ -z "$title" ]] && errors+="Title can't be blank. "
    echo "$errors"
}

# Callbacks
before_save_post() {
    : # Add any pre-save logic here
}

after_save_post() {
    : # Add any post-save logic here
}
