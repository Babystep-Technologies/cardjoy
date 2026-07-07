# Cardjoy Codebase

Open-source app for creating and sharing group cards and invitations. Hosted at
[cardjoy.app](https://cardjoy.app). **This repo is public** — never commit secrets.

## Project Structure

- `api/` - Rails backend (GraphQL API), all development within Docker
- `web/` - Consumer-facing React/TypeScript frontend (Vite)
- `admin/` - Admin interface (React/TypeScript, Vite)
- `docs/` - Documentation

## Deployment / infrastructure lives in a SEPARATE repo

All infra, Terraform, and deploy pipelines are in the **private `cardjoy-ops`** repo
(Cloud Run for the API, Firebase Hosting for the frontends). **Do not add infra here.** This repo
only holds the application; `cardjoy-ops` builds and deploys it from a git ref.

## Development Commands

Everything runs in Docker — no local Ruby/Node needed.

```bash
docker compose up          # start api + db + redis + web + admin
```

### Backend (api/)
```bash
docker compose exec api bundle exec rspec        # tests
docker compose exec api bundle exec rspec spec/path/to/spec.rb
docker compose exec api bundle exec rubocop      # style
docker compose exec api bundle exec srb tc       # Sorbet type check
docker compose exec api rails console
```

### Frontend (web/ and admin/)
```bash
docker compose exec web yarn test
docker compose exec web yarn lint
docker compose exec web yarn format
```

## Conventions & gotchas

- **Do NOT push to `main`.** Branch + open a PR. `main` is protected; app CI (`api-ci`,
  `web-ci`, `admin-ci`) runs on PRs.
- Commit format: `<type>(<scope>): <description>`. Before pushing: rspec, RuboCop, Sorbet, Prettier.
- **Config via env with credential fallback:** production reads `DB_*`, `GCS_*`, `GOOGLE_CLIENT_ID`,
  `ADDITIONAL_CORS_ORIGINS` from env (injected by `cardjoy-ops` Terraform), falling back to Rails
  encrypted credentials — so local dev is unaffected. See `api/config/database.yml`, `storage.yml`,
  the Google sign-in mutations, and `initializers/cors.rb`.
- **Optional frontend integrations:** GIPHY, Unsplash, and PostHog are gated on their `VITE_*` keys
  being present (blank = feature hidden, no crash). Keys are optional; see `web/.env.example`.
- **Test credentials are committed** (`api/config/credentials/test.key` + `test.yml.enc`, dummy
  values only) so CI/rspec works with no secret. Do not put real secrets in test credentials.
- Google sign-in is token-based (validates an ID token against `GOOGLE_CLIENT_ID`); no client secret.
