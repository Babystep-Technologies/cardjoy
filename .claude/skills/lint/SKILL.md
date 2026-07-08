---
name: lint
description: Run linting and formatting for the web and admin frontends
allowed-tools: Bash, Read, Edit, Grep, Glob
---

# Run Frontend Lint

Run linting and formatting checks for the React/TypeScript frontends (`web` and `admin`). All
commands run inside Docker.

## Usage

When invoked, run lint and the format check for both frontends. Pass an app name
(`/lint web` or `/lint admin`) to scope to one:

```bash
# web
docker compose exec web yarn lint
docker compose exec web yarn format-check

# admin
docker compose exec admin yarn lint
docker compose exec admin yarn format-check
```

To auto-fix formatting, run `yarn format` (instead of `format-check`) in the affected app.

## On Failure

If linting or formatting fails:
1. Review the errors reported
2. Fix the issues automatically using Edit tool when possible (or run `yarn format` for formatting)
3. Re-run the checks to verify fixes
