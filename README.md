# Cardjoy

A platform for creating and sharing group cards and invitations. The hosted product lives at
[cardjoy.app](https://cardjoy.app); this repository is its open-source codebase.

## Project structure

- `api/` — Rails backend (GraphQL API), developed inside Docker
- `web/` — consumer-facing React/TypeScript frontend
- `admin/` — admin dashboard (React/TypeScript)
- `docs/` — product documentation

## Getting started

### Prerequisites
- Docker and Docker Compose
- `make` (standard on macOS/Linux)

### Quick start

```bash
git clone git@github.com:Babystep-Technologies/cardjoy.git
cd cardjoy
make setup   # build containers, install deps, create & seed the database
make dev     # start the api, web, and admin dev servers
```

Then open:
- **Web** (consumer app): http://localhost:3001
- **Admin**: http://localhost:3002
- **API** (GraphQL): http://localhost:3000/graphql

`make setup` seeds the database (card styles, etc.) so the app is usable right away. Run `make` on
its own to see all available targets. Prefer raw Docker commands? See
[CONTRIBUTING.md](./CONTRIBUTING.md).

### Running tests & checks

```bash
make test    # backend RSpec suite
make lint    # RuboCop, Sorbet, and frontend lint/format checks
make check   # everything CI runs (test + lint + build)
```

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](./CONTRIBUTING.md) for local setup, the
test/lint workflow, and pull-request conventions.

## License

Licensed under the **GNU Affero General Public License v3.0** (AGPL-3.0). See [LICENSE](./LICENSE).

If you run a modified version of Cardjoy as a network service, the AGPL requires you to make your
modified source available to its users.
