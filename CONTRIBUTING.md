# Contributing to Cardjoy

Thanks for your interest in contributing! This guide covers local setup and the conventions we
follow.

## Local development

Everything runs in Docker — you don't need Ruby or Node installed locally.

```bash
git clone git@github.com:Babystep-Technologies/cardjoy.git
cd cardjoy
docker compose up
```

Services:
- Web (consumer): http://localhost:5173
- API: http://localhost:3000
- Admin: http://localhost:3002

## Running tests & linters

Run these before opening a pull request:

```bash
# Backend (Rails)
docker compose exec api bundle exec rspec        # tests
docker compose exec api bundle exec rubocop      # style
docker compose exec api bundle exec srb tc       # Sorbet type check

# Frontend (web / admin)
docker compose exec web yarn test
docker compose exec web yarn lint
docker compose exec web yarn format
```

## Pull requests

- Branch off `main`; do not push to `main` directly.
- Use the commit message format `<type>(<scope>): <description>`
  (e.g. `feat(api): add reminder scheduling`).
- Keep PRs focused; include a clear description of the change and how to verify it.
- Make sure tests, RuboCop/Sorbet, and Prettier all pass.

## Reporting bugs & requesting features

Please open a GitHub Issue with steps to reproduce (for bugs) or a clear description of the use case
(for features).

## License

By contributing, you agree that your contributions will be licensed under the project's
[AGPL-3.0 license](./LICENSE).
