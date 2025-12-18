#!/bin/bash

# Mini-tag template engine (no external deps required)
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
  if [[ -n "${!name}" ]]; then echo -n "${!name}"; return; fi
  if env | grep -q "^${name}="; then echo -n "${!name}"; return; fi
  echo -n ""
}

render::section_if() {
  local cond="$1"; local block="$2"
  if [[ -n "$cond" ]]; then render::process "$block"; fi
}

render::section_each() {
  local list_name="$1"; local block="$2"
  local idx=0
  local list_var="${list_name}[@]"
  local items=("${!list_var}")
  if [[ ${#items[@]} -eq 0 && -n "${!list_name}" ]]; then items=("${!list_name}"); fi
  for item in "${items[@]}"; do
    this="$item"; export this
    @index=$idx; export @index
    render::process "$block"
    idx=$((idx+1))
  done
}

render::partial() {
  local name="$1"; shift
  local path="$BALLS_VIEWS/${name}.html.tmpl"
  [ -f "$path" ] && render::apply_template "$path"
}

render::apply_template() {
  local template_path="$1"
  local content="$(cat "$template_path")"
  render::process "${content}"
}

render::process() {
  local input="$1"
  local output=""

  # Each blocks
  while [[ "$input" =~ (.*)\{\{#each ([^}]*)\}\}(.*)\{\{/each\}\}(.*) ]]; do
    local before="${BASH_REMATCH[1]}"
    local list="${BASH_REMATCH[2]}"
    local block="${BASH_REMATCH[3]}"
    local after="${BASH_REMATCH[4]}"
    output+="$before"
    output+="$(render::section_each "$list" "$block")"
    input="$after"
  done

  # If blocks
  while [[ "$input" =~ (.*)\{\{#if ([^}]*)\}\}(.*)\{\{/if\}\}(.*) ]]; do
    local before="${BASH_REMATCH[1]}"
    local cond="${BASH_REMATCH[2]}"
    local block="${BASH_REMATCH[3]}"
    local after="${BASH_REMATCH[4]}"
    output+="$before"
    output+="$(render::section_if "$(render::lookup "$cond")" "$block")"
    input="$after"
  done

  # Partials
  while [[ "$input" =~ (.*?)\{\{> ([^}]*)\}\}(.*) ]]; do
    output+="${BASH_REMATCH[1]}"
    output+="$(render::partial "${BASH_REMATCH[2]}")"
    input="${BASH_REMATCH[3]}"
  done

  # Raw interpolation
  local rest="$input"; local tmp=""
  while [[ "$rest" =~ (.*?)\{\{\{([^}]*)\}\}\}(.*) ]]; do
    tmp+="${BASH_REMATCH[1]}";
    tmp+="$(render::lookup "${BASH_REMATCH[2]}")";
    rest="${BASH_REMATCH[3]}";
  done
  input="$tmp$rest"

  # Escaped interpolation
  rest="$input"; tmp=""
  while [[ "$rest" =~ (.*?)\{\{([^}]*)\}\}(.*) ]]; do
    tmp+="${BASH_REMATCH[1]}";
    tmp+="$(render::escape_html "$(render::lookup "${BASH_REMATCH[2]}")")";
    rest="${BASH_REMATCH[3]}";
  done
  tmp+="$rest"

  echo -n "$output$tmp"
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

render_text() { echo -n "$1"; }

render_json() {
  local json="$1"
  http::content_type application/json 3>&1
  echo -n "$json"
}
