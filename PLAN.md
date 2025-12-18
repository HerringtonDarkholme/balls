# Plan: Bash on Balls (Rails-like in Bash)

## Goals & Constraints
- Deliver a Rails-inspired Bash framework with MVC, routing, views, models, and generators.
- External tools (e.g., `jq`) may be used optionally when present, but runtime must work without them.
- Templates use a built-in mini-tag parser (interpolation, if/each, partials, escaping).
- Persist data via simple file-backed store (`db.sh` key/value) by default; optional external tools like `jq` allowed but not required.
- Prefer concise testing harness (tiny assert helpers; `bats` only if present).
- Frontend interactions favor HTMX (`https://htmx.org/`) for progressive enhancement.

## Baseline Snapshot
- Current libs: `lib/router.sh`, `lib/server.sh`, `lib/view.sh` (esh-based), `lib/model.sh`, `lib/http.sh`, `lib/util.sh`.
- Routing currently matches static paths only; views compiled with `esh`; minimal model layer.

## Work Streams
1) **Routing & Server Pass**: tighten request parsing, header/body handling, HEAD/404/405 logic, static asset passthrough, per-request reload in dev.
2) **Mini-Tag View Engine**: replace/augment `esh` with tag parser supporting `{{ }}`, `{{{ }}}`, `{{#if}}`, `{{#each}}`, partials, layouts, HTML escaping.
3) **shql Data Layer**: wrap `shql` for CRUD, transactions, and migrations; add schema version tracking and per-env DB paths.
4) **Controllers & Filters**: define action context (`REQ_*`, params, strong params), before/after hooks, render/redirect helpers, error handling.
5) **Generators & CLI**: `balls new`, `balls s`, `balls g controller/model/migration`, `balls routes`, `balls db:migrate`, `balls c` console.
6) **Config & Envs**: `BALLS_ENV`, `.env` loader, `config/environments/*.sh`, secret management for signing/CSRF.
7) **Testing**: lightweight assert library for controllers/models/views; optional `bats` runner; fixtures for shql (temp DB per test).

## Mini-Tag Parser Plan
- Tokens: `{{var}}` (escaped), `{{{var}}}` (raw), `{{#if cond}}...{{/if}}`, `{{#each list}}...{{/each}}` with `{{this}}` and `{{@index}}`, `{{> partial with key=val}}`.
- Implementation: line-based tokenizer, simple stack for blocks, variable lookup from env/associative arrays; no arbitrary eval; HTML escape helper for interpolations.
- Layouts: wrap action view with `app/views/layouts/application.html.tmpl` by default; allow override per action.

## Data Layer (shql) Plan
- DB per environment: `db/development.sqlite`, `db/test.sqlite`, `db/production.sqlite`.
- Helpers: `model_find table id`, `model_where table sql params`, `model_insert table fields...`, `model_update table id fields...`, `model_delete table id`.
- Migrations: scripts in `db/migrate/*.sh` using `shql` SQL; track versions in `schema_migrations` table; `balls db:migrate` applies pending.
- Validations: per-model functions returning error messages; controllers gate saves.

## Testing Approach
- Default: tiny assert helpers (`assert_eq`, `assert_match`, `assert_status`) runnable via `balls test` script; no external deps required.
- If `bats` exists, allow `balls test --bats` to run `.bats` suites.
- Test helpers: fake request/response harness for controllers, temp DB for models, render diff for views/templates.

## Deliverables Checklist
- Mini-tag engine module and integration in `lib/view.sh` with layouts/partials.
- shql wrappers, migration runner, env-aware DB selection, sample migration.
- Controller/render helpers and route DSL enhancements (params, wildcards, middleware hooks).
- Generators and scaffolds for controllers, models, views, migrations.
- Test harness and example specs.
