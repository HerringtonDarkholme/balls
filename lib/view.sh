#!/bin/bash

# Mini-tag template engine (no external deps)
# Supports: {{var}} (escaped), {{{var}}} (raw), {{#if var}}...{{/if}}, {{#each list}}...{{/each}}, {{> partial}}

render::escape_html() {
  local s="$1"
  s=${s//&/&amp;}
  s=${s//</&lt;}
  s=${s//>/&gt;}
  s=${s//\"/&quot;}
  s=${s//"'"/&apos;}
  echo -n "$s"
}

render::lookup() {
  local name="$1"
  # First check explicit locals
  if [[ -n "${!name}" ]]; then
    echo -n "${!name}"
    return
  fi
  # Fallback to env vars
  if env | grep -q "^${name}="; then
    echo -n "${!name}"
    return
  fi
  echo -n ""
}

render::apply_template() {
  local template_path="$1"
  local content="$(cat "$template_path")"
  render::process "${content}"
}

render::process() {
  local input="$1"
  local output=""
  local rest="$input"
  while [[ "$rest" =~ (.*?)\{\{\{([^}]*)\}\}\}(.*) ]]; do
    output+="${BASH_REMATCH[1]}";
    output+="$(render::lookup "${BASH_REMATCH[2]}")";
    rest="${BASH_REMATCH[3]}";
  done
  input="$output$rest"
  output=""
  rest="$input"
  while [[ "$rest" =~ (.*?)\{\{([^}]*)\}\}(.*) ]]; do
    output+="${BASH_REMATCH[1]}";
    output+="$(render::escape_html "$(render::lookup "${BASH_REMATCH[2]}")")";
    rest="${BASH_REMATCH[3]}";
  done
  output+="$rest"
  echo -n "$output"
}

render::with_layout() {
  local body="$1"
  local layout="$BALLS_VIEWS/layouts/application.html.tmpl"
  local yield="$body"
  TITLE=${TITLE:-"Bash on Balls"}
  local title="$TITLE"
  local layout_content="$(cat "$layout")"
  layout_content=${layout_content//"{{{yield}}}"/$yield}
  layout_content=${layout_content//"{{yield}}"/$yield}
  layout_content=${layout_content//"{{title}}"/$title}
  echo "$layout_content"
}

render_view() {
  local view_path="$1"
  local tmpl="$BALLS_VIEWS/${view_path}.html.tmpl"
  local rendered="$(render::apply_template "$tmpl")"
  render::with_layout "$rendered"
}

render_text() {
  echo -n "$1"
}

render_json() {
  local json="$1"
  http::content_type application/json 3>&1
  echo -n "$json"
}
