#!/usr/bin/env bash
#
# Bash on Balls - View Renderer
#
# Provides template loading, interpolation, layouts, and partials
# Compatible with bash 3.2
#

# View helpers

# HTML escape special characters
# Usage: escaped=$(h "<script>alert('xss')</script>")
h() {
    local string="$1"
    string="${string//&/&amp;}"
    string="${string//</&lt;}"
    string="${string//>/&gt;}"
    string="${string//\"/&quot;}"
    string="${string//\'/&#39;}"
    echo "$string"
}

# Generate a link tag
# Usage: link_to "Click here" "/path"
# Usage: link_to "Delete" "/posts/1" class="btn btn-danger" data-method="delete"
link_to() {
    local text="$1"
    local href="$2"
    shift 2
    
    local attrs=""
    while [[ $# -gt 0 ]]; do
        attrs+=" $1"
        shift
    done
    
    echo "<a href=\"${href}\"${attrs}>${text}</a>"
}

# Generate a form tag
# Usage: form_with "/posts" "post"
# Usage: form_with "/posts/1" "put" id="edit-form"
form_with() {
    local action="$1"
    local method="${2:-post}"
    shift 2 2>/dev/null || shift
    
    local attrs=""
    while [[ $# -gt 0 ]]; do
        attrs+=" $1"
        shift
    done
    
    local real_method="post"
    local method_override=""
    
    # For PUT, PATCH, DELETE - use POST with _method override
    case "$method" in
        put|PUT|patch|PATCH|delete|DELETE)
            real_method="post"
            method_override="<input type=\"hidden\" name=\"_method\" value=\"${method}\">"
            ;;
        *)
            real_method="$method"
            ;;
    esac
    
    echo "<form action=\"${action}\" method=\"${real_method}\"${attrs}>"
    [[ -n "$method_override" ]] && echo "$method_override"
}

# End form tag
end_form() {
    echo "</form>"
}

# Generate a text input field
# Usage: text_field "title" value="Hello" class="form-control"
text_field() {
    local name="$1"
    shift
    
    local value=""
    local attrs=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            value=*) value="${1#value=}" ;;
            *) attrs+=" $1" ;;
        esac
        shift
    done
    
    echo "<input type=\"text\" name=\"${name}\" value=\"$(h "$value")\"${attrs}>"
}

# Generate a textarea
# Usage: text_area "body" value="Content" rows="5"
text_area() {
    local name="$1"
    shift
    
    local value=""
    local attrs=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            value=*) value="${1#value=}" ;;
            *) attrs+=" $1" ;;
        esac
        shift
    done
    
    echo "<textarea name=\"${name}\"${attrs}>$(h "$value")</textarea>"
}

# Generate a submit button
# Usage: submit_button "Create Post"
submit_button() {
    local text="${1:-Submit}"
    shift
    
    local attrs=""
    while [[ $# -gt 0 ]]; do
        attrs+=" $1"
        shift
    done
    
    echo "<button type=\"submit\"${attrs}>${text}</button>"
}

# Generate a label
# Usage: label_for "title" "Post Title"
label_for() {
    local field="$1"
    local text="${2:-$field}"
    echo "<label for=\"${field}\">${text}</label>"
}

# Load a template file and return its contents
load_template() {
    local template_path="$1"
    
    if [[ -f "$template_path" ]]; then
        cat "$template_path"
    else
        echo "<!-- Template not found: $template_path -->"
        return 1
    fi
}

# Process template interpolation
# Replaces {{variable}} with variable value
# Replaces {{> partial}} with partial contents
# Replaces {{# code }} with executed code output
interpolate_template() {
    local content="$1"
    local result=""
    
    while [[ -n "$content" ]]; do
        # Check for {{
        if [[ "$content" == *"{{"* ]]; then
            # Get text before {{
            local before="${content%%\{\{*}"
            result+="$before"
            
            # Get the tag content
            local rest="${content#*\{\{}"
            
            if [[ "$rest" == "}}"* ]]; then
                # Empty tag, skip
                content="${rest#\}\}}"
                continue
            fi
            
            # Find closing }}
            local tag="${rest%%\}\}*}"
            content="${rest#*\}\}}"
            
            # Trim whitespace from tag
            tag="${tag#"${tag%%[![:space:]]*}"}"
            tag="${tag%"${tag##*[![:space:]]}"}"
            
            # Process tag based on prefix
            case "$tag" in
                ">"*)
                    # Partial: {{> partial_name}}
                    local partial_name="${tag#>}"
                    partial_name="${partial_name#"${partial_name%%[![:space:]]*}"}"
                    local partial_content=$(render_partial "$partial_name")
                    result+="$partial_content"
                    ;;
                "#if "*)
                    # Conditional: {{#if variable}} ... {{/if}}
                    local condition="${tag#\#if }"
                    # Find matching {{/if}}
                    local if_content="${content%%\{\{/if\}\}*}"
                    content="${content#*\{\{/if\}\}}"
                    
                    # Check condition
                    eval "local cond_value=\"\${$condition}\""
                    if [[ -n "$cond_value" ]]; then
                        local processed=$(interpolate_template "$if_content")
                        result+="$processed"
                    fi
                    ;;
                "#each "*)
                    # Loop: {{#each items}} ... {{/each}}
                    # Note: Limited implementation for bash
                    local var_name="${tag#\#each }"
                    local loop_content="${content%%\{\{/each\}\}*}"
                    content="${content#*\{\{/each\}\}}"
                    
                    # Get the array variable
                    eval "local items=\"\${$var_name}\""
                    
                    # For CSV data, split by newline
                    while IFS= read -r item; do
                        if [[ -n "$item" ]]; then
                            # Set item fields as variables
                            local processed=$(interpolate_template "$loop_content")
                            result+="$processed"
                        fi
                    done <<< "$items"
                    ;;
                "#"*)
                    # Exec block: {{# code }} - must come after #if and #each
                    local code="${tag#\#}"
                    code="${code#"${code%%[![:space:]]*}"}"
                    local exec_result=$(eval "$code" 2>/dev/null)
                    result+="$exec_result"
                    ;;
                "/if"|"/each")
                    # Closing tags - should already be handled, skip
                    ;;
                "yield")
                    # Yield placeholder for layout (replaced separately)
                    result+="{{yield}}"
                    ;;
                "{"*)
                    # Raw/unescaped output: {{{variable}}}
                    # Tag is "{var}" - strip the leading {
                    # Content starts with "}" - need to consume it
                    local raw_var="${tag#\{}"
                    raw_var="${raw_var#"${raw_var%%[![:space:]]*}"}"
                    raw_var="${raw_var%"${raw_var##*[![:space:]]}"}"
                    # Consume the trailing } that's part of }}}
                    content="${content#\}}"
                    eval "local raw_value=\"\${$raw_var}\""
                    result+="$raw_value"
                    ;;
                *)
                    # Variable interpolation: {{variable}}
                    # HTML-escaped by default to prevent XSS
                    # Skip if it looks like a closing tag
                    if [[ "$tag" != /* ]]; then
                        eval "local var_value=\"\${$tag}\""
                        result+="$(h "$var_value")"
                    fi
                    ;;
            esac
        else
            # No more tags
            result+="$content"
            break
        fi
    done
    
    echo "$result"
}

# Render a partial
# Usage: render_partial "shared/header"
render_partial() {
    local name="$1"
    local partial_path="${APP_PATH}/app/views/${name}.sh.html"
    
    # Also check for _partial naming convention
    if [[ ! -f "$partial_path" ]]; then
        local dir=$(dirname "$name")
        local base=$(basename "$name")
        partial_path="${APP_PATH}/app/views/${dir}/_${base}.sh.html"
    fi
    
    if [[ -f "$partial_path" ]]; then
        local content=$(load_template "$partial_path")
        interpolate_template "$content"
    else
        echo "<!-- Partial not found: $name -->"
    fi
}

# Render a view with optional layout
# Usage: render_view "posts/index" "application"
render_view() {
    local template="$1"
    local layout="${2:-application}"
    
    local template_path="${APP_PATH}/app/views/${template}.sh.html"
    
    if [[ ! -f "$template_path" ]]; then
        echo "<h1>Template Not Found</h1><p>Could not find: ${template}</p>"
        return 1
    fi
    
    # Load and process template
    local template_content=$(load_template "$template_path")
    local view_content=$(interpolate_template "$template_content")
    
    # Load and process layout
    if [[ "$layout" != "none" && "$layout" != "false" ]]; then
        local layout_path="${APP_PATH}/app/views/layouts/${layout}.sh.html"
        
        if [[ -f "$layout_path" ]]; then
            local layout_content=$(load_template "$layout_path")
            # Replace {{yield}} with view content
            layout_content="${layout_content//\{\{yield\}\}/$view_content}"
            # Process layout interpolation
            interpolate_template "$layout_content"
        else
            # No layout found, just return view content
            echo "$view_content"
        fi
    else
        echo "$view_content"
    fi
}
