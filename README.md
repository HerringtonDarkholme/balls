# Bash on Balls

A bash-native, netcat-served parody of Rails. Build web apps with shell scripts!

> "Rails-like DX, bash-scale features."

<img width="926" height="513" alt="image" src="https://github.com/user-attachments/assets/2dd197c9-6da5-45a3-9bbf-0d966f2a44d9" />


## Features

- Rails-like routing DSL (`get`, `post`, `resources`)
- Controllers with actions, `before_action`, and helpers
- View templates with layouts, partials, and interpolation
- Flat-file models (CSV) with validations and hooks
- Generators for scaffolds, controllers, and models
- [Tailwind CSS](https://tailwindcss.com) via CDN for styling
- [HTMX](https://htmx.org) for modern, JavaScript-light interactivity
- Built-in test runner
- Zero extra runtimes — pure bash + standard Unix tools

## Requirements

- macOS (tested) or Linux
- Bash 3.2+
- BSD/GNU netcat (`nc`)
- Standard Unix utilities: `sed`, `awk`, `date`, `mktemp`, `cut`, `tr`

## Quick Start

```bash
# Clone the repo
git clone https://github.com/example/balls.git
cd balls

# Create a new app
./balls new myapp
cd myapp

# Start the server
../balls server

# Visit http://localhost:14514
```

## CLI Commands

```bash
balls new <app>                           # Create new application
balls server [path] [port]                # Start development server (default: port 14514)
balls routes [path]                       # Display route table
balls generate controller <name> [actions...]    # Generate controller
balls generate model <name> [fields...]          # Generate model
balls generate scaffold <name> [fields...]       # Generate full CRUD scaffold
balls test [path]                         # Run test suite
balls help                                # Show help
balls version                             # Show version
```

### Examples

```bash
# Create a new app
./balls new blog

# Generate a scaffold with fields
./balls generate scaffold post title:string body:text

# Generate just a controller with specific actions
./balls generate controller comments index show create

# Generate just a model with fields
./balls generate model comment body:string post_id:integer

# Start server on custom port
./balls server ./myapp 8080

# View routes
./balls routes ./myapp

# Run all tests
./balls test

# Run specific test file
./balls test test/unit/routing_test.sh

# Run only unit tests
./balls test test/unit
```

## Directory Structure

```
myapp/
├── app/
│   ├── controllers/        # Controller scripts (*_controller.sh)
│   ├── models/             # Model definitions (*.sh)
│   └── views/              # View templates (*.sh.html)
│       └── layouts/        # Layout templates
├── config/
│   └── routes.sh           # Route definitions
├── db/                     # Data storage (*.csv, *.counter)
├── log/                    # Log files (access.log)
├── public/                 # Static files (served directly)
├── tmp/cache/              # Fragment cache
└── .env                    # Environment configuration
```

## Routing

Define routes in `config/routes.sh`:

```bash
# Basic routes
get "/" "home#index"
get "/about" "pages#about"
post "/contact" "pages#submit"

# Route with parameter
get "/posts/:id" "posts#show"
get "/posts/:id/edit" "posts#edit"

# RESTful resources (creates all 7 CRUD routes + 1 PATCH)
resources "posts"
# Generates:
#   GET    /posts          -> posts#index
#   GET    /posts/new      -> posts#new
#   POST   /posts          -> posts#create
#   GET    /posts/:id      -> posts#show
#   GET    /posts/:id/edit -> posts#edit
#   PUT    /posts/:id      -> posts#update
#   PATCH  /posts/:id      -> posts#update
#   DELETE /posts/:id      -> posts#destroy

# Root route helper
root "home#index"  # Same as: get "/" "home#index"
```

## Controllers

Controllers live in `app/controllers/` and define `*_action` functions:

```bash
#!/usr/bin/env bash
# app/controllers/posts_controller.sh

# Check if request is from HTMX
is_htmx_request() {
    [[ "$HX_REQUEST" == "true" ]]
}

# Before actions (optional)
before_action() {
    # Run before every action
    # Return non-zero to halt request
}

index_action() {
    posts=$(model_all "posts")
    render "posts/index"
}

show_action() {
    post=$(model_find "posts" "$id")
    if [[ -z "$post" ]]; then
        set_flash error "Post not found"
        redirect_to "/posts"
        return
    fi
    render "posts/show"
}

create_action() {
    if model_create "posts"; then
        set_flash notice "Post created!"
        redirect_to "/posts"
    else
        set_flash error "Failed to create post"
        render "posts/new"
    fi
}

destroy_action() {
    model_destroy "posts" "$id"

    if is_htmx_request; then
        # For HTMX: redirect via header
        header "HX-Redirect" "/posts"
        render_html ""
    else
        redirect_to "/posts"
    fi
}
```

### Controller Helpers

```bash
render "view/path"           # Render a view template
redirect_to "/path"          # HTTP redirect (302)
redirect_to "/path" 301      # Redirect with custom status

set_flash notice "message"   # Set flash message for next request
set_flash error "message"

param "name"                 # Get request parameter
param "name" "default"       # With default value

params_expect "title" "body" # Validate required params (returns error if missing)

status 404                   # Set response status
header "X-Custom" "value"    # Set response header

render_text "plain text"     # Render plain text
render_json '{"key":"val"}'  # Render JSON
render_html "<h1>Hi</h1>"    # Render HTML directly

# HTMX detection
is_htmx_request              # Returns true if HX-Request header is present
$HX_REQUEST                  # "true" if HTMX request
$HX_TARGET                   # Target element ID
$HX_TRIGGER                  # Triggering element ID
```

## Views

Views are `.sh.html` templates in `app/views/`:

```html
<!-- app/views/posts/show.sh.html -->
<h1>{{title}}</h1>
<p>{{body}}</p>
<p>Posted on: {{# date -r "$created_at" "+%Y-%m-%d" }}</p>

<a href="/posts/{{id}}/edit">Edit</a>
<a href="/posts">Back to list</a>
```

### Template Syntax

```html
{{variable}}              <!-- Variable interpolation -->
{{# shell_command }}      <!-- Execute shell and insert output -->

{{#if variable}}          <!-- Conditional (shows if variable is non-empty) -->
  <p>Variable is set!</p>
{{/if}}

{{> partials/header}}     <!-- Include partial from app/views/partials/header.sh.html -->
```

### Layouts

Layouts wrap views and use `{{yield}}` for content. Tailwind CSS and HTMX are included by default:

```html
<!-- app/views/layouts/application.sh.html -->
<!DOCTYPE html>
<html>
<head>
    <title>{{title}} - My App</title>
    <script src="https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4"></script>
    <script src="https://unpkg.com/htmx.org@2.0.4"></script>
    <style type="text/tailwindcss">
        @theme {
            --color-primary: #667eea;
            --color-primary-hover: #5a6fd6;
            --color-danger: #e74c3c;
            --color-danger-hover: #c0392b;
        }
    </style>
</head>
<body hx-boost="true" class="min-h-screen bg-gray-100">
    {{#if flash_notice}}
    <div class="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded mb-4">
        {{flash_notice}}
    </div>
    {{/if}}
    {{#if flash_error}}
    <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
        {{flash_error}}
    </div>
    {{/if}}
    
    {{yield}}
</body>
</html>
```

### View Helpers

```bash
# In templates, use these helpers:
{{# link_to "Click me" "/path" }}
{{# link_to "Edit" "/posts/$id/edit" "class=btn" }}

{{# form_with "/posts" "post" }}
{{# form_with "/posts/$id" "put" }}

{{# text_field "title" "$title" }}
{{# text_area "body" "$body" }}
{{# submit_button "Save" }}

{{# h "$user_input" }}    <!-- HTML escape -->
```

## HTMX Integration

Bash on Balls uses [HTMX](https://htmx.org) as its built-in JavaScript framework for modern, interactive UIs without writing JavaScript.

### Automatic Features

- **hx-boost**: Enabled on `<body>` by default — all links and forms use AJAX automatically
- **HTMX headers**: The server parses `HX-Request`, `HX-Target`, `HX-Trigger` headers

### Using HTMX in Views

```html
<!-- Delete button with confirmation -->
<button hx-delete="/posts/{{id}}"
        hx-target="#post-{{id}}"
        hx-swap="outerHTML"
        hx-confirm="Are you sure?">
    Delete
</button>

<!-- Form with HTMX -->
<form hx-post="/posts"
      hx-target="body"
      hx-push-url="true">
    <input type="text" name="title">
    <button type="submit">Create</button>
</form>

<!-- Inline editing -->
<div hx-get="/posts/{{id}}/edit"
     hx-trigger="click"
     hx-swap="outerHTML">
    Click to edit
</div>
```

### HTMX Response Headers

Controllers can set HTMX response headers:

```bash
destroy_action() {
    model_destroy "posts" "$id"

    if is_htmx_request; then
        # Redirect after delete
        header "HX-Redirect" "/posts"
        render_html ""
    else
        redirect_to "/posts"
    fi
}
```

Available HTMX headers:
- `HX-Redirect` — Client-side redirect
- `HX-Refresh` — Full page refresh
- `HX-Trigger` — Trigger client-side events

## Tailwind CSS

Bash on Balls uses [Tailwind CSS](https://tailwindcss.com) via CDN for styling. No build step required!

### Custom Theme Colors

Define custom colors in your layout using `@theme`:

```html
<style type="text/tailwindcss">
    @theme {
        --color-primary: #667eea;
        --color-primary-hover: #5a6fd6;
        --color-danger: #e74c3c;
        --color-danger-hover: #c0392b;
    }
</style>
```

Then use them in your views:

```html
<button class="bg-primary hover:bg-primary-hover text-white px-4 py-2 rounded-lg">
    Submit
</button>

<button class="bg-danger hover:bg-danger-hover text-white px-4 py-2 rounded-lg">
    Delete
</button>
```

### Example Components

```html
<!-- Card -->
<div class="bg-white rounded-lg shadow-md p-6">
    <h2 class="text-xl font-semibold mb-2">Title</h2>
    <p class="text-gray-600">Content goes here</p>
</div>

<!-- Form input -->
<input type="text" 
       class="w-full px-4 py-2 border border-gray-300 rounded-lg 
              focus:ring-2 focus:ring-primary focus:border-transparent 
              outline-none transition">

<!-- Alert -->
<div class="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded">
    Success message
</div>
```

## Models

Models are defined in `app/models/` and use CSV storage:

```bash
#!/usr/bin/env bash
# app/models/post.sh

MODEL_NAME="post"
MODEL_FIELDS=("id" "title" "body" "created_at")

# Validations (optional)
validate_post() {
    local errors=()
    [[ -z "$title" ]] && errors+=("Title can't be blank")
    [[ ${#title} -lt 3 ]] && errors+=("Title must be at least 3 characters")
    printf '%s\n' "${errors[@]}"
}

# Callbacks (optional)
before_save_post() {
    # Set timestamp on create
    [[ -z "$created_at" ]] && created_at=$(date +%s)
}

after_save_post() {
    # Run after successful save
    :
}
```

### Model Functions

```bash
model_all "posts"              # Get all records (newline-separated)
model_find "posts" "$id"       # Find by ID
model_create "posts"           # Create from params
model_update "posts" "$id"     # Update from params
model_destroy "posts" "$id"    # Delete record
model_count "posts"            # Count records
model_where "posts" "field" "value"  # Find by field value

# Parse a record into variables
parse_record "posts" "$record"
# Now $id, $title, $body, etc. are available
```

### Data Storage

Data is stored in CSV format in `db/`:

```
db/posts.csv       # Data file
db/posts.counter   # Auto-increment counter
```

## Static Files

Files in `public/` are served directly:

```
public/style.css   -> GET /style.css
public/js/app.js   -> GET /js/app.js
public/favicon.ico -> GET /favicon.ico
```

## Testing

Create tests in `test/` directory:

```bash
#!/usr/bin/env bash
# test/unit/my_test.sh

source "$(dirname "$0")/../test_helper.sh"

echo "=== My Tests ==="

test_start "something works"
result=$(some_function)
if assert_equal "expected" "$result"; then
    test_pass
else
    test_fail
fi

test_summary
```

### Test Helpers

```bash
test_start "description"       # Start a test
test_pass                      # Mark as passed
test_fail "message"            # Mark as failed

assert_equal "expected" "actual" "message"
assert_contains "haystack" "needle" "message"
assert_not_empty "$value" "message"
assert_file_exists "/path/to/file"
assert_dir_exists "/path/to/dir"
assert_success                 # Check last exit code was 0
assert_failure $?              # Check last exit code was non-zero

setup_temp_dir                 # Create temp directory ($TEMP_DIR)
cleanup_temp_dir               # Remove temp directory
```

Run tests:

```bash
./balls test                   # Run all tests
./balls test test/unit         # Run unit tests only
./balls test test/e2e          # Run E2E tests only
./balls test path/to/test.sh   # Run specific test file
```

## Environment Configuration

Create `.env` in your app directory:

```bash
PORT=14514
HOST=127.0.0.1
BALLS_ENV=development
DB_BACKEND=csv
```

## macOS Notes

This framework is designed for macOS with these considerations:

- **BSD netcat**: macOS `nc` lacks the `-k` (keep-alive) flag. The server uses a FIFO-based accept loop to handle multiple requests.
- **Bash 3.2**: macOS ships with Bash 3.2, which lacks associative arrays. The framework uses indexed arrays and `PARAM_*` variable naming conventions instead.
- **BSD sed**: Uses `sed -E` for extended regex. In-place editing uses `sed -i ''`.
- **No external dependencies**: Works with standard macOS utilities.

## Project Structure

```
balls/
├── balls                # Main CLI executable
├── lib/
│   ├── routing.sh       # Routing DSL
│   ├── controller.sh    # Controller runtime
│   ├── view.sh          # View renderer
│   ├── model.sh         # Model/ORM layer
│   ├── server.sh        # HTTP server (nc-based)
│   └── test.sh          # Test runner
├── example/             # Example application
└── test/                # Test suite
    ├── unit/            # Unit tests
    ├── e2e/             # End-to-end tests
    └── test_helper.sh   # Test utilities
```

## Running the Example App

```bash
cd balls
./balls server example/ 14514
# Visit http://localhost:14514
# Try http://localhost:14514/posts for CRUD operations
```

## License

MIT
