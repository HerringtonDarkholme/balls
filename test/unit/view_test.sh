#!/usr/bin/env bash
#
# Unit Tests: View Renderer
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/../test_helper.sh"
source "$PROJECT_ROOT/lib/view.sh"

echo "Running View Tests..."
echo ""

# Setup temp app for testing
setup_temp_dir
mkdir -p "$TEMP_DIR/app/views/posts"
mkdir -p "$TEMP_DIR/app/views/shared"
mkdir -p "$TEMP_DIR/app/views/layouts"

APP_PATH="$TEMP_DIR"

# Create test templates
cat > "$TEMP_DIR/app/views/posts/index.sh.html" << 'EOF'
<h1>{{title}}</h1>
<p>{{message}}</p>
EOF

cat > "$TEMP_DIR/app/views/posts/show.sh.html" << 'EOF'
<article>
    <h1>{{post_title}}</h1>
    <p>{{post_body}}</p>
    {{> shared/footer}}
</article>
EOF

cat > "$TEMP_DIR/app/views/shared/_footer.sh.html" << 'EOF'
<footer>Posted by {{author}}</footer>
EOF

cat > "$TEMP_DIR/app/views/layouts/application.sh.html" << 'EOF'
<!DOCTYPE html>
<html>
<head><title>{{page_title}}</title></head>
<body>
{{yield}}
</body>
</html>
EOF

cat > "$TEMP_DIR/app/views/posts/conditional.sh.html" << 'EOF'
{{#if show_admin}}
<div class="admin">Admin Panel</div>
{{/if}}
<p>Regular content</p>
EOF

# Test: HTML escape helper
test_start "h escapes < and >"
result=$(h "<script>")
if [[ "$result" == "&lt;script&gt;" ]]; then
    test_pass
else
    test_fail "$result"
fi

test_start "h escapes &"
result=$(h "A & B")
if [[ "$result" == "A &amp; B" ]]; then
    test_pass
else
    test_fail "$result"
fi

test_start "h escapes quotes"
result=$(h '"test"')
if [[ "$result" == "&quot;test&quot;" ]]; then
    test_pass
else
    test_fail "$result"
fi

test_start "h escapes single quotes"
result=$(h "it's")
if [[ "$result" == "it&#39;s" ]]; then
    test_pass
else
    test_fail "$result"
fi

# Test: link_to helper
test_start "link_to generates anchor tag"
result=$(link_to "Home" "/")
if [[ "$result" == '<a href="/">Home</a>' ]]; then
    test_pass
else
    test_fail "$result"
fi

test_start "link_to includes attributes"
result=$(link_to "Click" "/path" 'class="btn"')
if [[ "$result" == *'class="btn"'* ]]; then
    test_pass
else
    test_fail "$result"
fi

# Test: form_with helper
test_start "form_with generates form tag"
result=$(form_with "/posts" "post")
if [[ "$result" == '<form action="/posts" method="post">' ]]; then
    test_pass
else
    test_fail "$result"
fi

test_start "form_with adds method override for PUT"
result=$(form_with "/posts/1" "put")
if [[ "$result" == *'_method" value="put"'* ]]; then
    test_pass
else
    test_fail "$result"
fi

test_start "form_with adds method override for DELETE"
result=$(form_with "/posts/1" "delete")
if [[ "$result" == *'_method" value="delete"'* ]]; then
    test_pass
else
    test_fail "$result"
fi

# Test: text_field helper
test_start "text_field generates input"
result=$(text_field "title")
if [[ "$result" == '<input type="text" name="title" value="">' ]]; then
    test_pass
else
    test_fail "$result"
fi

test_start "text_field includes value"
result=$(text_field "title" 'value=Hello')
if [[ "$result" == *'value="Hello"'* ]]; then
    test_pass
else
    test_fail "$result"
fi

# Test: text_area helper
test_start "text_area generates textarea"
result=$(text_area "body")
if [[ "$result" == '<textarea name="body"></textarea>' ]]; then
    test_pass
else
    test_fail "$result"
fi

# Test: submit_button helper
test_start "submit_button generates button"
result=$(submit_button "Save")
if [[ "$result" == '<button type="submit">Save</button>' ]]; then
    test_pass
else
    test_fail "$result"
fi

# Test: Template interpolation
test_start "interpolate_template replaces variables"
title="Hello World"
result=$(interpolate_template "<h1>{{title}}</h1>")
if [[ "$result" == "<h1>Hello World</h1>" ]]; then
    test_pass
else
    test_fail "$result"
fi

test_start "interpolate_template handles multiple variables"
title="Title"
name="John"
result=$(interpolate_template "{{title}} by {{name}}")
if [[ "$result" == "Title by John" ]]; then
    test_pass
else
    test_fail "$result"
fi

test_start "interpolate_template handles exec blocks"
result=$(interpolate_template "Result: {{# echo hello }}")
if [[ "$result" == "Result: hello" ]]; then
    test_pass
else
    test_fail "$result"
fi

# Test: Partial rendering
test_start "render_partial loads partial file"
author="John Doe"
result=$(render_partial "shared/footer")
if [[ "$result" == *"Posted by John Doe"* ]]; then
    test_pass
else
    test_fail "$result"
fi

# Test: Full view rendering
test_start "render_view renders template"
title="Posts"
message="Welcome to posts"
result=$(render_view "posts/index" "none")
if [[ "$result" == *"<h1>Posts</h1>"* ]] && [[ "$result" == *"Welcome to posts"* ]]; then
    test_pass
else
    test_fail "$result"
fi

test_start "render_view wraps in layout"
page_title="My Site"
title="Test"
message="Content"
result=$(render_view "posts/index" "application")
if [[ "$result" == *"<!DOCTYPE html>"* ]] && [[ "$result" == *"<h1>Test</h1>"* ]]; then
    test_pass
else
    test_fail "$result"
fi

test_start "render_view includes partials"
post_title="My Post"
post_body="Post content"
author="Jane"
result=$(render_view "posts/show" "none")
if [[ "$result" == *"<h1>My Post</h1>"* ]] && [[ "$result" == *"Posted by Jane"* ]]; then
    test_pass
else
    test_fail "$result"
fi

# Test: Conditionals
test_start "{{#if}} shows content when variable is set"
show_admin="true"
result=$(render_view "posts/conditional" "none")
if [[ "$result" == *"Admin Panel"* ]]; then
    test_pass
else
    test_fail "$result"
fi

test_start "{{#if}} hides content when variable is empty"
show_admin=""
result=$(render_view "posts/conditional" "none")
if [[ "$result" != *"Admin Panel"* ]] && [[ "$result" == *"Regular content"* ]]; then
    test_pass
else
    test_fail "$result"
fi

# Test: Missing template handling
test_start "render_view handles missing template gracefully"
result=$(render_view "nonexistent/template" "none")
if [[ "$result" == *"Template Not Found"* ]]; then
    test_pass
else
    test_fail "$result"
fi

# Test: XSS prevention - variables are escaped by default
test_start "{{variable}} escapes HTML to prevent XSS"
xss_input="<script>alert('xss')</script>"
result=$(interpolate_template "{{xss_input}}")
if [[ "$result" == "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;" ]]; then
    test_pass
else
    test_fail "Expected escaped HTML, got: $result"
fi

# Test: Raw output with triple braces
test_start "{{{variable}}} outputs raw unescaped HTML"
raw_html="<b>bold</b>"
result=$(interpolate_template "{{{raw_html}}}")
if [[ "$result" == "<b>bold</b>" ]]; then
    test_pass
else
    test_fail "Expected raw HTML, got: $result"
fi

# Test: h() helper escapes HTML
test_start "h() helper escapes HTML entities"
result=$(h "<script>alert('xss')</script>")
if [[ "$result" == "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;" ]]; then
    test_pass
else
    test_fail "$result"
fi

# Cleanup
cleanup_temp_dir

test_summary
exit $?
