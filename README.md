# Bash on Balls

A toy Rails-style web framework in Bash. Conventions over config, tiny surface area, no hard deps (optionally uses `shql`, `jq` if present), and HTMX-friendly views.

## Quick Start
```bash
# install shql if you want SQLite models (optional)
# brew install shql  # or get from https://github.com/tnm/shql

# run the sample app
./bin/balls server
# open http://localhost:3000
```

## Features (Snapshot)
- Routing DSL (`b:GET / posts#index`) with reload in dev
- Controllers with render helpers (views, text, JSON)
- Mini-tag templates with layouts/partials; HTMX script included by default
- `shql`-backed models and migrations (optional)
- Static file serving from `public/`

## App Structure
```
app/
  controllers/   # controller scripts (actions as functions)
  models/        # model helpers
  views/         # templates (*.html.tmpl) + layouts
config/
  config.sh      # base config
  environments/  # per-env settings
  routes.sh      # route definitions via DSL
bin/balls        # CLI entry (server, migrate)
db/              # sqlite files + migrations
public/          # static assets
```

## Routing
`config/routes.sh`:
```bash
b:GET /           home#index
b:POST /posts     posts#create
b:GET /posts/:id  posts#show   # (params matching planned)
```

## Controllers
`app/controllers/posts.sh`:
```bash
#!/bin/bash

posts#index() {
  TITLE="All Posts"
  render_view posts/index
}

posts#create() {
  # params parsing/strong params planned
  render_text "Created"  # or redirect_to /posts
}
```

## Views (Mini-Tag Templates)
`app/views/posts/index.html.tmpl`:
```html
<h1>{{title}}</h1>
<ul>
  {{#each posts}}
    <li>{{this.title}}</li>
  {{/each}}
</ul>
<button hx-get="/posts" hx-target="ul">Refresh</button>
```
Layouts live in `app/views/layouts/application.html.tmpl` and receive `{{{yield}}}`.

## Models (file-backed via `db.sh`)
`app/models/post.sh`:
```bash
post_create() {
  # store payload as a simple string (JSON, csv, etc.)
  local payload="title=$1|body=$2"
  model::create posts "$payload"
}

post_find() {
  model::find posts "$1"
}

post_all() {
  model::all posts
}
```

Storage is append-only key/value in `x.db` by default. Keys are `table:id`, values are raw payload strings. Migrations are not needed for this file store.

## CLI (current)
- `./bin/balls server` (alias `s`): start HTTP server on `$BALLS_PORT` (default 3000)
- `./bin/balls migrate`: run pending `shql` migrations

## HTMX
Default layout includes HTMX script. Use `hx-get`, `hx-post`, `hx-target`, etc., in templates for progressive enhancement. Responses can be full HTML or partial snippets (e.g., render a partial view for `hx-target`).

## Testing (planned concise harness)
- Provide tiny shell `assert_*` helpers; optionally run `bats` if installed.
- Controller tests: invoke actions with fake request env; Model tests: temp SQLite via `shql`; View tests: render template and compare output.

## Using Bash on Balls
### 1) Optional tools
- `jq` for richer JSON parsing/rendering (optional). Framework still runs without it.

### 2) Run the sample app
```bash
./bin/balls server       # default port 3000
# open http://localhost:3000
```

### 3) Define routes
`config/routes.sh`
```bash
b:GET /           home#index
b:GET /posts      posts#index
b:POST /posts     posts#create
b:GET /posts/:id  posts#show   # param routing planned
```

### 4) Write controllers
`app/controllers/posts.sh`
```bash
#!/bin/bash

posts#index() {
  TITLE="All Posts"
  # make posts available to the view (string, csv, etc.)
  render_view posts/index
}

posts#create() {
  # parse params (strong params planned)
  render_text "Created"
}
```

### 5) Create views (mini-tag templates + HTMX)
`app/views/posts/index.html.tmpl`
```html
<h1>{{title}}</h1>
<ul>
  {{#each posts}}
    <li>{{this.title}}</li>
  {{/each}}
</ul>
<button hx-get="/posts" hx-target="ul">Refresh</button>
```
Layouts live in `app/views/layouts/application.html.tmpl` with `{{{yield}}}`.

### 6) Add models (file-backed)
`app/models/post.sh`
```bash
post_create() {
  model::create posts "title=$1|body=$2"
}
post_find() {
  model::find posts "$1"
}
post_all() {
  model::all posts
}
```
No migrations needed for the file-backed store.

### 7) Static files
Place assets in `public/` (e.g., `public/style.css`). Requests are served before hitting routes.

### 8) Environment & config
- `BALLS_ENV` (`development` default), `BALLS_PORT`, `BALLS_RELOAD`, `BALLS_DB_FILE` can be set via env.
- Base config: `config/config.sh`; per-env overrides in `config/environments/*.sh`.

### 9) CLI commands (current)
- `./bin/balls server` or `./bin/balls s` — start server
- `./bin/balls migrate` — no-op placeholder (kept for compatibility)

### 10) HTMX tips
- Use `hx-get/hx-post` to fetch partials; controllers can render a partial view to target an element.
- Return snippets (e.g., a list item) for `hx-target` to replace or append.

### 11) Troubleshooting
- If `shql` is missing, model/migration helpers will fail; either install or avoid DB calls.
- If `jq` is missing, JSON helpers fall back to simple string handling; prefer form-encoded bodies.

## Notes
- Optional deps: `shql` for SQLite, `jq` for better JSON parsing. Code should still run without them (fall back to simple behavior).
- Mini-tag engine currently supports escaped/raw interpolation and layout yield; `if/each/partials` coming next per plan.
