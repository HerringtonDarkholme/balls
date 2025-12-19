# Bash on Balls — Build Plan

Bash on Balls is a bash-native, netcat-served parody of Rails: it mirrors Rails conventions (routes/controllers/views/models/scaffolds) in shell form with zero extra runtimes, aiming for “Rails-like DX, bash-scale features.”

## Constraints
- Target macOS default tools: bash, BSD nc, sed, awk, date, mktemp, uuidgen (fallback counters), printf, cut, tr. Optional: jq.
- HTTP server must use `nc`; BSD nc lacks `-k`, so implement accept loop in shell.
- Keep everything in bash with standard CLI utilities. External commands are fine as subprocesses
- Ban additional programming language runtimes; avoid extra dependencies.

## Architecture & Layout
- CLI: `balls` entrypoint script
- Runtime libs: `lib/` (routing, controller exec, view renderer, model store, server, helpers)
- Templates: `templates/` for generators
- Example app: `example/` shipped app
- Support dirs/files: `db/`, `tmp/cache`, `log/`, `README.md`, `.env.example`

## Architecture Overview
- Rails analogs: routing DSL (`resources`), controllers/actions with before hooks, views with layout/partials/helpers, flat-file models, generators for scaffolds, and a tiny server.
- Execution model: `nc` accepts connections, dispatcher maps requests to controller actions, actions call views/models, responses emitted as HTTP text.
- Data model: CSV/JSON files with auto-increment counters, simple validations and callbacks implemented as shell functions.
- Templating: layout + partials + interpolation; helpers for links/forms akin to Rails helpers in a constrained shell form.
- Auth/caching: lightweight tokens/basic-auth and fragment cache stubs to parody Rails features without heavy machinery.

## Feature Checklist
1) CLI commands: `balls new <app>`, `balls server [path]`, `balls routes`, `balls generate controller|model|scaffold`.
2) Routing DSL: `get/post/put/patch/delete "path" controller#action`; `resources <name>` expands CRUD; `balls routes` prints table.
3) Controller runtime: source controller, call `<action>_action`; helpers `render`, `redirect_to`, `set_flash`, `before_action` list, `params_expect`; parse query + form body.
4) Views: layout + `yield`, partial include, helpers `link_to`, `form_with`-like (method override `_method`), `h` escape; template interpolation `{{var}}` plus minimal exec blocks.
5) Models: flat-file CSV/JSON under `db/`; auto-increment via counter file; CRUD helpers; presence validation; hooks (`before_save`/`after_save`).
6) Server: `nc` accept loop, parse request line/headers/body, dispatch, return status/headers/body; method override via `_method`; logging to stdout/file.
7) Caching stub: fragment cache in `tmp/cache`.
8) Auth toggle: per-route/controller `allow_unauthenticated`; basic token/basic-auth from `.env`.
9) Generators: controller/model/scaffold using templates.
10) Example app: posts CRUD (index/show/new/create/edit/update/destroy), routes/controllers/views, sample data; runnable via `./balls server example`.
11) Docs: README with quickstart, usage, conventions, macOS `nc` caveats, optional jq.

## Testing Notes
- Add lightweight smoke tests per component (CLI, routing parse, controller dispatch, view render, model CRUD, server request/response) using bash scripts that assert exit codes/output snippets.
- Provide an end-to-end script that boots the server, hits a route, and checks response text.

## Execution Steps
1. Scaffold repo layout (lib/, templates/, example/, db/, tmp/cache, log/, .env.example, README placeholder).
2. Implement CLI `balls` dispatcher and help.
3. Build routing DSL + routes printer.
4. Implement controller runtime + helpers (render, redirect, flash, before_action, params_expect).
5. Implement view renderer (layout, partials, helpers, interpolation).
6. Implement model store (CSV/JSON) with CRUD, validation, hooks.
7. Implement `nc` server loop + dispatcher.
8. Add caching stub and auth toggle.
9. Implement generators using templates.
10. Assemble example app and ensure it runs with server.
11. Finalize README and sanity-check commands.
