---
name: checks
description: Run every quality gate CI runs — RuboCop, Sorbet, RSpec, and web/admin lint/format/build
allowed-tools: Bash, Read, Edit, Grep, Glob
---

# Run all quality gates

Run the full set of checks that CI enforces, so a change is green before opening a PR. Everything
runs inside Docker. This mirrors `make check`.

## Commands

Backend (`api-ci`):

```bash
docker compose exec api bundle exec rubocop        # Ruby style
docker compose exec api bundle exec srb tc         # Sorbet type check
docker compose exec api bundle exec rspec          # tests
```

Frontends (`web-ci`, `admin-ci`) — run for both `web` and `admin`:

```bash
docker compose exec web   yarn lint
docker compose exec web   yarn format-check
docker compose exec web   yarn build
docker compose exec admin yarn lint
docker compose exec admin yarn format-check
docker compose exec admin yarn build
```

Or simply:

```bash
make check
```

## On Failure

- **Sorbet** errors about a gem or a generated (DSL) method usually mean the RBIs are stale.
  Regenerate them the way CI does, then re-check:
  ```bash
  docker compose exec api bundle exec tapioca gems
  docker compose exec api bundle exec tapioca dsl
  docker compose exec api bundle exec srb tc
  ```
- **RuboCop** offenses: try `docker compose exec api bundle exec rubocop -a` for autocorrectable ones.
- **Prettier** (`format-check`) failures: run `yarn format` in the affected app to fix.
- **RSpec / build** failures: read the failure, fix the code, and re-run just that gate before
  re-running the whole suite.

Report which gates passed and which failed; do not claim success unless every gate is green.
