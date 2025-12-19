# Bash on Balls — TODO

A comprehensive step-by-step implementation checklist with macOS-specific verification steps.

---

## Prerequisites Check

- [ ] **Step 0.1: Verify macOS Bash version**
  - Task: Check bash version (macOS ships with bash 3.2)
  - Verify: `bash --version` — should show version info
  - Note: Some features may need bash 3.2 compatibility

- [ ] **Step 0.2: Verify BSD nc (netcat) availability**
  - Task: Confirm nc is available and BSD variant
  - Verify: `nc -h 2>&1 | head -5` — should show BSD netcat help
  - Note: BSD nc lacks `-k` (keep-alive), requires accept loop

- [ ] **Step 0.3: Verify required macOS utilities**
  - Task: Check sed, awk, date, mktemp, uuidgen, printf, cut, tr
  - Verify: `which sed awk date mktemp uuidgen printf cut tr` — all should return paths
  - Note: macOS sed is BSD sed (different from GNU sed)

- [ ] **Step 0.4: Check optional jq availability**
  - Task: Check if jq is installed (optional)
  - Verify: `which jq || echo "jq not installed (optional)"`

---

## Phase 1: Repository Layout Scaffold

- [ ] **Step 1.1: Create directory structure**
  - Task: Create `lib/`, `templates/`, `example/`, `db/`, `tmp/cache/`, `log/`, `test/`
  - Verify: `ls -la` — all directories should exist
  
- [ ] **Step 1.2: Create .env.example file**
  - Task: Create `.env.example` with placeholder config (AUTH_TOKEN, PORT, etc.)
  - Verify: `cat .env.example` — should display config template

- [ ] **Step 1.3: Create README.md placeholder**
  - Task: Create initial `README.md` with project title
  - Verify: `cat README.md` — should display content

- [ ] **Step 1.4: Create main `balls` CLI entrypoint**
  - Task: Create executable `balls` script with shebang
  - Verify: `file balls && head -1 balls` — should show "Bourne-Again shell script" and `#!/usr/bin/env bash`

- [ ] **Step 1.5: Make balls executable**
  - Task: `chmod +x balls`
  - Verify: `ls -l balls` — should show `-rwxr-xr-x` permissions

- [ ] **Step 1.6: Unit Test — Verify directory structure**
  - Task: Create `test/unit/scaffold_test.sh` to verify all directories exist
  - Verify: `bash test/unit/scaffold_test.sh` — should pass all assertions

---

## Phase 2: CLI Dispatcher & Help

- [ ] **Step 2.1: Implement CLI command dispatcher**
  - Task: Parse first argument to route to subcommands (new, server, routes, generate)
  - Verify: `./balls` — should show help/usage message

- [ ] **Step 2.2: Implement help command**
  - Task: `./balls help` or `./balls --help` shows available commands
  - Verify: `./balls help` — should list: new, server, routes, generate

- [ ] **Step 2.3: Implement version flag**
  - Task: `./balls --version` shows version
  - Verify: `./balls --version` — should output version string

- [ ] **Step 2.4: Implement `balls new <app>` command**
  - Task: Create new app skeleton in specified directory
  - Verify: `./balls new testapp && ls testapp/` — should show app structure

- [ ] **Step 2.5: Clean up test app**
  - Task: Remove test app created in verification
  - Verify: `rm -rf testapp && [ ! -d testapp ]` — directory should not exist

- [ ] **Step 2.6: Unit Test — CLI dispatcher**
  - Task: Create `test/unit/cli_test.sh` testing help, version, unknown commands
  - Verify: `bash test/unit/cli_test.sh` — should pass all assertions

---

## Phase 3: Routing DSL

- [ ] **Step 3.1: Create lib/routing.sh**
  - Task: Implement routing DSL functions
  - Verify: `source lib/routing.sh && type get` — should show function definition

- [ ] **Step 3.2: Implement HTTP verb functions**
  - Task: Create `get`, `post`, `put`, `patch`, `delete` functions
  - Verify: `source lib/routing.sh && get "/test" "test#index" && echo $?` — should return 0

- [ ] **Step 3.3: Implement route storage**
  - Task: Store routes in array (bash 3.2 compatible, no associative arrays)
  - Verify: Source routing, add routes, verify internal route list exists

- [ ] **Step 3.4: Implement `resources` macro**
  - Task: `resources posts` expands to index/show/new/create/edit/update/destroy routes
  - Verify: `source lib/routing.sh && resources posts && echo "${ROUTES[@]}"` — should show 7 routes

- [ ] **Step 3.5: Implement route matching**
  - Task: Match incoming path/method to controller#action, support path params (`:id`)
  - Verify: Create test that matches `GET /posts/123` to `posts#show` with id=123

- [ ] **Step 3.6: Implement `balls routes` command**
  - Task: Print route table (method, path, controller#action)
  - Verify: `./balls routes example/` — should display formatted table

- [ ] **Step 3.7: Unit Test — Routing DSL**
  - Task: Create `test/unit/routing_test.sh` testing verbs, resources, matching
  - Verify: `bash test/unit/routing_test.sh` — should pass all assertions

---

## Phase 4: Controller Runtime

- [ ] **Step 4.1: Create lib/controller.sh**
  - Task: Controller loading and action dispatch
  - Verify: `source lib/controller.sh && type dispatch_action` — function exists

- [ ] **Step 4.2: Implement controller sourcing**
  - Task: Load controller file from `app/controllers/`
  - Verify: Create mock controller, source it, verify function available

- [ ] **Step 4.3: Implement action dispatch**
  - Task: Call `<action>_action` function from controller
  - Verify: Create test controller with index_action, dispatch to it

- [ ] **Step 4.4: Implement `render` helper**
  - Task: Render view template with variables
  - Verify: `render "posts/index"` — should output rendered content

- [ ] **Step 4.5: Implement `redirect_to` helper**
  - Task: Set 302 redirect response
  - Verify: `redirect_to "/posts"` — should set Location header

- [ ] **Step 4.6: Implement `set_flash` helper**
  - Task: Set flash message for next request (cookie-based)
  - Verify: `set_flash "notice" "Created!"` — should set flash

- [ ] **Step 4.7: Implement `before_action` system**
  - Task: Register and execute before hooks
  - Verify: Define before_action, verify it runs before action

- [ ] **Step 4.8: Implement `params_expect` helper**
  - Task: Validate required params exist
  - Verify: `params_expect "title" "body"` — should fail if missing

- [ ] **Step 4.9: Implement query string parser**
  - Task: Parse `?foo=bar&baz=qux` into params array
  - Verify: Parse test query string, verify params populated

- [ ] **Step 4.10: Implement form body parser**
  - Task: Parse `application/x-www-form-urlencoded` POST body
  - Verify: Parse test body, verify params populated

- [ ] **Step 4.11: Unit Test — Controller runtime**
  - Task: Create `test/unit/controller_test.sh` testing dispatch, helpers, params
  - Verify: `bash test/unit/controller_test.sh` — should pass all assertions

---

## Phase 5: View Renderer

- [ ] **Step 5.1: Create lib/view.sh**
  - Task: View rendering engine
  - Verify: `source lib/view.sh && type render_view` — function exists

- [ ] **Step 5.2: Implement template loading**
  - Task: Load `.sh.html` templates from `app/views/`
  - Verify: Create test template, load it, verify content

- [ ] **Step 5.3: Implement `{{var}}` interpolation**
  - Task: Replace `{{variable}}` with shell variable values
  - Verify: Set var, render template with `{{var}}`, verify substitution

- [ ] **Step 5.4: Implement layout system**
  - Task: Wrap view in layout, `{{yield}}` for content
  - Verify: Render view with layout, verify layout wraps content

- [ ] **Step 5.5: Implement partial rendering**
  - Task: `{{> partial_name}}` includes partial
  - Verify: Create partial, include in view, verify rendered

- [ ] **Step 5.6: Implement `link_to` helper**
  - Task: `link_to "Text" "/path"` → `<a href="/path">Text</a>`
  - Verify: `link_to "Home" "/"` — should output anchor tag

- [ ] **Step 5.7: Implement `form_with` helper**
  - Task: Generate form with method override support
  - Verify: `form_with "/posts" "post"` — should output form with hidden `_method`

- [ ] **Step 5.8: Implement `h` escape helper**
  - Task: HTML escape special characters (`<`, `>`, `&`, `"`, `'`)
  - Verify: `h "<script>"` — should output `&lt;script&gt;`

- [ ] **Step 5.9: Implement exec blocks**
  - Task: `{{# shell_code }}` executes and inserts output
  - Verify: `{{# echo "hello" }}` — should output "hello"

- [ ] **Step 5.10: Unit Test — View renderer**
  - Task: Create `test/unit/view_test.sh` testing interpolation, layout, partials, helpers
  - Verify: `bash test/unit/view_test.sh` — should pass all assertions

---

## Phase 6: Model Store

- [ ] **Step 6.1: Create lib/model.sh**
  - Task: Flat-file model CRUD operations
  - Verify: `source lib/model.sh && type model_create` — function exists

- [ ] **Step 6.2: Implement CSV storage backend**
  - Task: Store records as CSV in `db/<model>.csv`
  - Verify: Create record, verify CSV file created with data

- [ ] **Step 6.3: Implement JSON storage backend (optional)**
  - Task: If jq available, support JSON storage
  - Verify: Create record with JSON backend, verify file format

- [ ] **Step 6.4: Implement auto-increment ID**
  - Task: Counter file in `db/<model>.counter` for IDs
  - Verify: Create 3 records, verify IDs are 1, 2, 3

- [ ] **Step 6.5: Implement `model_all` (index)**
  - Task: Return all records for a model
  - Verify: Create records, call model_all, verify all returned

- [ ] **Step 6.6: Implement `model_find` (show)**
  - Task: Find record by ID
  - Verify: `model_find posts 1` — should return record with id=1

- [ ] **Step 6.7: Implement `model_create` (create)**
  - Task: Create new record with provided fields
  - Verify: Create record, verify in storage file

- [ ] **Step 6.8: Implement `model_update` (update)**
  - Task: Update existing record by ID
  - Verify: Update record, verify changes persisted

- [ ] **Step 6.9: Implement `model_destroy` (delete)**
  - Task: Delete record by ID
  - Verify: Delete record, verify removed from file

- [ ] **Step 6.10: Implement presence validation**
  - Task: `validate_presence "title"` fails if empty
  - Verify: Try create with empty field, should fail

- [ ] **Step 6.11: Implement `before_save` hook**
  - Task: Call before_save function if defined
  - Verify: Define hook, verify it runs before save

- [ ] **Step 6.12: Implement `after_save` hook**
  - Task: Call after_save function if defined
  - Verify: Define hook, verify it runs after save

- [ ] **Step 6.13: Unit Test — Model store**
  - Task: Create `test/unit/model_test.sh` testing CRUD, validations, hooks
  - Verify: `bash test/unit/model_test.sh` — should pass all assertions

---

## Phase 7: HTTP Server

- [ ] **Step 7.1: Create lib/server.sh**
  - Task: BSD nc-based HTTP server
  - Verify: `source lib/server.sh && type start_server` — function exists

- [ ] **Step 7.2: Implement nc accept loop**
  - Task: While loop with nc to accept connections (BSD nc workaround for no `-k`)
  - Verify: Start server, `curl http://localhost:14514` responds

- [ ] **Step 7.3: Implement request line parser**
  - Task: Parse `GET /path HTTP/1.1` into method, path, version
  - Verify: Parse test request line, verify variables set

- [ ] **Step 7.4: Implement header parser**
  - Task: Parse headers into variables (bash 3.2 compatible approach)
  - Verify: Parse test headers, verify Content-Type accessible

- [ ] **Step 7.5: Implement body reader**
  - Task: Read body based on Content-Length header
  - Verify: POST with body, verify body captured

- [ ] **Step 7.6: Implement `_method` override**
  - Task: Support `_method=PUT` in form body for PUT/PATCH/DELETE
  - Verify: POST with `_method=DELETE`, verify dispatched as DELETE

- [ ] **Step 7.7: Implement response builder**
  - Task: Build HTTP response with status, headers, body
  - Verify: Build 200 response, verify proper HTTP format

- [ ] **Step 7.8: Implement request dispatcher**
  - Task: Route request to controller action via routing
  - Verify: GET /posts dispatches to posts#index

- [ ] **Step 7.9: Implement static file serving**
  - Task: Serve files from `public/` directory
  - Verify: Create `public/test.txt`, GET it, verify content

- [ ] **Step 7.10: Implement request logging**
  - Task: Log method, path, status to stdout and `log/access.log`
  - Verify: Make request, verify log entry

- [ ] **Step 7.11: Implement `balls server [path]` command**
  - Task: Start server for app at path (default: current dir)
  - Verify: `./balls server example/` — server starts on port 14514

- [ ] **Step 7.12: Unit Test — Server components**
  - Task: Create `test/unit/server_test.sh` testing request/response parsing
  - Verify: `bash test/unit/server_test.sh` — should pass all assertions

---

## Phase 8: Caching & Auth

- [ ] **Step 8.1: Create lib/cache.sh**
  - Task: Fragment caching helpers
  - Verify: `source lib/cache.sh && type cache_fragment` — function exists

- [ ] **Step 8.2: Implement fragment cache write**
  - Task: `cache_fragment "key" "content"` writes to `tmp/cache/`
  - Verify: Cache content, verify file created

- [ ] **Step 8.3: Implement fragment cache read**
  - Task: `get_cached_fragment "key"` returns cached content
  - Verify: Cache then read, verify content matches

- [ ] **Step 8.4: Implement cache expiration**
  - Task: TTL-based expiration using file mtime
  - Verify: Cache with TTL, wait, verify expires after time

- [ ] **Step 8.5: Unit Test — Cache**
  - Task: Create `test/unit/cache_test.sh` testing read/write/expiration
  - Verify: `bash test/unit/cache_test.sh` — should pass all assertions

- [ ] **Step 8.6: Create lib/auth.sh**
  - Task: Basic authentication helpers
  - Verify: `source lib/auth.sh && type authenticate` — function exists

- [ ] **Step 8.7: Implement token auth**
  - Task: Check `Authorization: Bearer <token>` against `.env` AUTH_TOKEN
  - Verify: Request with valid token passes, invalid fails

- [ ] **Step 8.8: Implement basic auth**
  - Task: Check `Authorization: Basic <base64>` credentials
  - Verify: Request with valid basic auth passes

- [ ] **Step 8.9: Implement `allow_unauthenticated` toggle**
  - Task: Skip auth for specific routes/actions
  - Verify: Mark route public, verify no auth required

- [ ] **Step 8.10: Unit Test — Auth**
  - Task: Create `test/unit/auth_test.sh` testing token, basic auth, toggle
  - Verify: `bash test/unit/auth_test.sh` — should pass all assertions

---

## Phase 9: Generators

- [ ] **Step 9.1: Create templates/controller.sh.template**
  - Task: Controller boilerplate template
  - Verify: `cat templates/controller.sh.template` — shows template

- [ ] **Step 9.2: Create templates/model.sh.template**
  - Task: Model boilerplate template
  - Verify: `cat templates/model.sh.template` — shows template

- [ ] **Step 9.3: Create templates/views/*.template**
  - Task: View templates for index/show/new/edit/form partial
  - Verify: `ls templates/views/` — shows template files

- [ ] **Step 9.4: Implement `balls generate controller <name> [actions]`**
  - Task: Generate controller with specified actions
  - Verify: `./balls generate controller comments index show` — creates files

- [ ] **Step 9.5: Implement `balls generate model <name> [fields]`**
  - Task: Generate model with specified fields
  - Verify: `./balls generate model comment body:string post_id:integer` — creates files

- [ ] **Step 9.6: Implement `balls generate scaffold <name> [fields]`**
  - Task: Generate model + controller + views + routes
  - Verify: `./balls generate scaffold article title:string body:text` — creates all files

- [ ] **Step 9.7: Verify generators are idempotent-safe**
  - Task: Re-running generator should warn, not overwrite
  - Verify: Generate twice, verify no data loss on second run

- [ ] **Step 9.8: Unit Test — Generators**
  - Task: Create `test/unit/generator_test.sh` testing all generator commands
  - Verify: `bash test/unit/generator_test.sh` — should pass all assertions

---

## Phase 10: Example Application

- [ ] **Step 10.1: Create example/config/routes.sh**
  - Task: Define routes for posts CRUD
  - Verify: `cat example/config/routes.sh` — shows resources posts

- [ ] **Step 10.2: Create example/app/controllers/posts_controller.sh**
  - Task: Implement all CRUD actions (index, show, new, create, edit, update, destroy)
  - Verify: Source controller, verify all `*_action` functions exist

- [ ] **Step 10.3: Create example/app/views/posts/*.sh.html**
  - Task: Create index, show, new, edit views
  - Verify: `ls example/app/views/posts/` — shows 4+ view files

- [ ] **Step 10.4: Create example/app/views/layouts/application.sh.html**
  - Task: Create main layout with yield
  - Verify: `cat example/app/views/layouts/application.sh.html` — shows layout with {{yield}}

- [ ] **Step 10.5: Create example/app/models/post.sh**
  - Task: Define post model with validations
  - Verify: Source model, verify validate functions exist

- [ ] **Step 10.6: Create example/db/ structure**
  - Task: Create db directory with sample data
  - Verify: `ls example/db/` — shows posts.csv or similar

- [ ] **Step 10.7: Create example/.env**
  - Task: Environment config (PORT, AUTH_TOKEN)
  - Verify: `cat example/.env` — shows config vars

- [ ] **Step 10.8: Create example/public/ with static assets**
  - Task: Add basic CSS file for styling
  - Verify: `ls example/public/` — shows style.css

---

## Phase 11: Integration & E2E Tests

- [ ] **Step 11.1: Create test/integration/server_integration_test.sh**
  - Task: Test full request/response cycle through server
  - Verify: `bash test/integration/server_integration_test.sh` — passes

- [ ] **Step 11.2: Create test/e2e/smoke_test.sh**
  - Task: Boot server, hit routes, verify responses
  - Verify: `bash test/e2e/smoke_test.sh` — passes

- [ ] **Step 11.3: E2E test: List posts**
  - Task: Start server, GET /posts, verify HTML response
  - Verify: `curl http://localhost:14514/posts` — returns posts list HTML

- [ ] **Step 11.4: E2E test: Create post**
  - Task: POST /posts with form data
  - Verify: `curl -X POST -d "title=Test&body=Content" http://localhost:14514/posts` — redirects

- [ ] **Step 11.5: E2E test: Show post**
  - Task: GET /posts/1
  - Verify: `curl http://localhost:14514/posts/1` — shows post detail

- [ ] **Step 11.6: E2E test: Update post**
  - Task: POST /posts/1 with _method=PUT
  - Verify: `curl -X POST -d "_method=PUT&title=Updated" http://localhost:14514/posts/1` — updates

- [ ] **Step 11.7: E2E test: Delete post**
  - Task: POST /posts/1 with _method=DELETE
  - Verify: `curl -X POST -d "_method=DELETE" http://localhost:14514/posts/1` — deletes

---

## Phase 12: Documentation & Polish

- [ ] **Step 12.1: Write README.md quickstart**
  - Task: Installation and basic usage instructions
  - Verify: Follow quickstart steps, verify they work

- [ ] **Step 12.2: Document CLI commands**
  - Task: Document all balls commands with examples
  - Verify: Each documented command works as described

- [ ] **Step 12.3: Document conventions**
  - Task: File naming, directory structure, DSL syntax
  - Verify: README explains all conventions

- [ ] **Step 12.4: Document macOS nc caveats**
  - Task: Explain BSD nc differences and limitations
  - Verify: Caveats section exists with workarounds

- [ ] **Step 12.5: Document optional jq usage**
  - Task: Explain JSON backend requires jq
  - Verify: jq section explains installation and usage

- [ ] **Step 12.6: Update .gitignore**
  - Task: Ignore tmp/, log/*.log, .env, db/*.csv (except examples)
  - Verify: `cat .gitignore` — shows appropriate patterns

---

## Phase 13: Test Runner & CI

- [ ] **Step 13.1: Create test runner script**
  - Task: `./balls test` runs all tests
  - Verify: `./balls test` — executes and reports results

- [ ] **Step 13.2: Add test summary output**
  - Task: Report pass/fail counts, exit with appropriate code
  - Verify: Run tests, see summary, check exit code

- [ ] **Step 13.3: Create test helpers**
  - Task: `test/test_helper.sh` with assert functions
  - Verify: Source helper, use assert_equal, assert_contains

---

## macOS-Specific Notes

### BSD vs GNU Differences
- `sed -i ''` (BSD) vs `sed -i` (GNU) — use `sed -i ''` on macOS
- `date` flags differ — avoid GNU-specific flags like `-d`
- `mktemp` works but template format may differ
- Arrays: bash 3.2 lacks associative arrays (`declare -A`) — use indexed arrays with conventions

### BSD nc (netcat) Limitations
- No `-k` flag for persistent listening
- Must implement accept loop manually with while loop
- Consider using named pipes (FIFOs) for bidirectional communication
- Connection closes after each request — this is expected behavior

### Bash 3.2 Compatibility
- No associative arrays — use naming conventions like `PARAMS_key=value`
- No `declare -A` — use indexed arrays or environment variables
- No `|&` for stderr redirect — use `2>&1 |`
- No `lastpipe` option — avoid relying on it

### Testing on macOS
- All verification commands assume macOS environment
- Test with default bash (`/bin/bash` is bash 3.2)
- Optionally test with newer bash if installed via Homebrew (`/opt/homebrew/bin/bash`)
- Use `curl` for HTTP testing (pre-installed on macOS)
