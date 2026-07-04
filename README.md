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

### Run it locally

```bash
git clone git@github.com:Babystep-Technologies/cardjoy.git
cd cardjoy
docker compose up
```

Then open:
- **Web**: http://localhost:5173
- **API**: http://localhost:3000
- **Admin**: http://localhost:3002

### Running tests

```bash
# Backend (Rails / RSpec)
docker compose exec api bundle exec rspec

# Frontend
docker compose exec web yarn test
docker compose exec web yarn lint
```

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](./CONTRIBUTING.md) for local setup, the
test/lint workflow, and pull-request conventions.

## License

Licensed under the **GNU Affero General Public License v3.0** (AGPL-3.0). See [LICENSE](./LICENSE).

If you run a modified version of Cardjoy as a network service, the AGPL requires you to make your
modified source available to its users.
