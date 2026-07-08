# Contributing to Cardjoy

Thanks for your interest in contributing! This guide covers local setup and the conventions we
follow.

## Local development

Everything runs in Docker — you don't need Ruby or Node installed locally. A `Makefile` wraps the
common Docker commands.

```bash
git clone git@github.com:Babystep-Technologies/cardjoy.git
cd cardjoy
make setup   # build containers, install deps, create & seed the database
make dev     # start the api, web, and admin dev servers
make logs    # follow the server logs
```

Services:
- Web (consumer): http://localhost:3001
- Admin: http://localhost:3002
- API (GraphQL): http://localhost:3000/graphql

`make setup` runs `db:seed`, which loads the card **styles** (background/font colors) the app needs
to render the create-card page. Run `make` with no target to list every shortcut.

### Behind the Make targets

Each target is a thin wrapper around Docker, if you prefer to run things directly:

```bash
docker compose up -d                             # start containers
docker compose exec api ./bin/rails db:prepare   # create/migrate the database
docker compose exec api ./bin/rails db:seed      # load seed data (styles, ...)
docker compose exec api ./bin/server             # start the API (rails server)
docker compose exec web yarn dev                 # start the web dev server
docker compose exec admin yarn dev               # start the admin dev server
```

## Running tests & linters

Run these before opening a pull request (or just `make check`, which runs them all):

```bash
make test    # backend RSpec suite
make lint    # RuboCop, Sorbet, and web/admin lint + format checks
make build   # type-check and build the frontends (mirrors CI)
```

Under the hood:

```bash
docker compose exec api bundle exec rspec        # backend tests
docker compose exec api bundle exec rubocop      # Ruby style
docker compose exec api bundle exec srb tc       # Sorbet type check
docker compose exec web   yarn lint              # web ESLint
docker compose exec web   yarn format-check      # web Prettier
docker compose exec admin yarn lint              # admin ESLint
docker compose exec admin yarn format-check      # admin Prettier
```

## Troubleshooting

- **App looks empty / "no styles" on the create-card page** — the database hasn't been seeded. Run
  `make seed` (or `docker compose exec api ./bin/rails db:seed`).
- **API errors about missing tables / pending migrations** — run `make db` to create and migrate the
  database, then `make dev`.
- **`make dev` fails with "A server is already running"** — a stale PID file. Run `make restart`,
  then `make dev` again.
- **Frontend build fails after pulling new changes** — dependencies changed. Re-run `make deps` (or
  `docker compose exec web yarn install`).
- **Nothing responds on the ports** — make sure the containers are up (`make up`) and the dev servers
  are started (`make dev`); follow `make logs` to see boot output.
- **Start over from scratch** — `make down && make setup`.

## Pull requests

- Branch off `main`; do not push to `main` directly.
- Use the commit message format `<type>(<scope>): <description>`
  (e.g. `feat(api): add reminder scheduling`).
- Keep PRs focused; include a clear description of the change and how to verify it.
- Make sure tests, RuboCop/Sorbet, and Prettier all pass.

## Reporting bugs & requesting features

Open a [new issue](https://github.com/Babystep-Technologies/cardjoy/issues/new/choose) and pick the
**Bug report** or **Feature request** form. For features, fill in the **acceptance criteria** — a
concrete checklist of what "done" means. Precise criteria make a proposal easy to review and easy to
build.

## Building a feature

See [docs/DEVELOPMENT.md](./docs/DEVELOPMENT.md) for the step-by-step patterns (backend GraphQL
mutation, frontend page) and the exact quality gates, and
[docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) for the system map.

## AI-assisted contributions

Accepted, well-specified issues can be built by an AI assistant and opened as a PR for review. This
is **off by default**; see [docs/AI_WORKFLOW.md](./docs/AI_WORKFLOW.md) for how it works and how a
maintainer enables it. A human reviewer and CI gate every PR, AI-authored or not.

## License

By contributing, you agree that your contributions will be licensed under the project's
[AGPL-3.0 license](./LICENSE).
