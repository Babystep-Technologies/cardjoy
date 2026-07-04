# Cardjoy Codebase

## Project Structure

- `api/` - Rails backend (all development within Docker)
- `web/` - Consumer-facing React/TypeScript frontend (all development within Docker)
- `admin/` - Admin interface
- `docs/` - Documentation

## Development Commands

### Backend (api/)
All Rails commands must be run inside Docker:
```bash
docker compose exec api <command>
```

Examples:
- Run rspec tests: `docker compose exec api bundle exec rspec`
- Run specific test: `docker compose exec api bundle exec rspec spec/path/to/spec.rb`
- Rails console: `docker compose exec api rails console`
- Run migrations: `docker compose exec api rails db:migrate`

### Frontend (web/)
All frontend commands must be run inside Docker:
```bash
docker compose exec web <command>
```

Examples:
- Format code: `docker compose exec web yarn format`
- Lint code: `docker compose exec web yarn lint`
- Run tests: `docker compose exec web yarn test`

### Workflow

- Do NOT directly push to main. Always create a feature branch and open a pull request for review.
- Follow the commit message format: `<type>(<scope>): <description>`
- Before pushing, ensure all tests pass and run sorbet and rubocop and prettier to check for type errors and code style issues.
