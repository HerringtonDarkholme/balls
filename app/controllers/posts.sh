#!/bin/bash

posts#index() {
  TITLE="Posts"
  posts=("1|title=Hello|body=World")
  render_view posts/index
}

posts#show() {
  local id="$REQ_PARAMS_id"
  TITLE="Post $id"
  post="$(model::find posts "$id")"
  render_view posts/show
}

posts#create() {
  local title="${REQ_PARAMS_title}"
  local body="${REQ_PARAMS_body}"
  local payload="title=$title|body=$body"
  local id=$(model::create posts "$payload")
  http::status 302 3>&1
  http::header "Location" "/posts/$id" 3>&1
  echo
}
