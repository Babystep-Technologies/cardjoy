# Cardjoy Codebase

Open-source app for creating and sharing group cards and invitations. Hosted at
[cardjoy.app](https://cardjoy.app). **This repo is public** — never commit secrets.

## Project Structure

- `api/` - Rails backend (GraphQL API), all development within Docker
- `web/` - Consumer-facing React/TypeScript frontend (Vite)
- `admin/` - Admin interface (React/TypeScript, Vite)
- `docs/` - Documentation ([ARCHITECTURE](docs/ARCHITECTURE.md), [DEVELOPMENT](docs/DEVELOPMENT.md))

This repo holds the **application only**. Do not add deployment/infrastructure config here.

## Key docs & skills

- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — how the system fits together.
- **[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)** — how to build a feature (backend + frontend
  patterns, with the exact quality-gate commands). Start here for any change.
- Skills in `.claude/skills/`: `build-from-issue` (issue → PR), `add-graphql-mutation`,
  `add-frontend-page`, `checks` (all gates), `lint`, `rspec`.

## Development Commands

Everything runs in Docker — no local Ruby/Node needed. A `Makefile` wraps the common commands:

```bash
make setup   # build, install deps, create & seed the database
make dev     # start api :3000, web :3001, admin :3002
make check   # run every quality gate (test + lint + build)
```

### Backend (api/)
```bash
docker compose exec api bundle exec rspec        # tests
docker compose exec api bundle exec rspec spec/path/to/spec.rb
docker compose exec api bundle exec rubocop      # style
docker compose exec api bundle exec srb tc       # Sorbet type check
docker compose exec api ./bin/rails console
```

### Frontend (web/ and admin/)
```bash
docker compose exec web yarn lint          # ESLint (also: admin)
docker compose exec web yarn format-check  # Prettier check (yarn format to fix)
docker compose exec web yarn build         # tsc type-check + build
```

## Conventions & gotchas

- **Do NOT push to `main`.** Branch + open a PR. `main` is protected; app CI (`api-ci`,
  `web-ci`, `admin-ci`) runs on PRs.
- Commit format: `<type>(<scope>): <description>`. Before pushing: rspec, RuboCop, Sorbet, Prettier.
- **Config via env with credential fallback:** production reads `DB_*`, `GCS_*`, `GOOGLE_CLIENT_ID`,
  `ADDITIONAL_CORS_ORIGINS` from environment variables, falling back to Rails encrypted
  credentials — so local dev is unaffected. See `api/config/database.yml`, `storage.yml`, the
  Google sign-in mutations, and `initializers/cors.rb`.
- **Optional frontend integrations:** GIPHY, Unsplash, and PostHog are gated on their `VITE_*` keys
  being present (blank = feature hidden, no crash). Keys are optional; see `web/.env.example`.
- **Test credentials are committed** (`api/config/credentials/test.key` + `test.yml.enc`, dummy
  values only) so CI/rspec works with no secret. Do not put real secrets in test credentials.
- Google sign-in is token-based (validates an ID token against `GOOGLE_CLIENT_ID`); no client secret.
