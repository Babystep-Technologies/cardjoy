---
name: lint
description: Run linting and formatting for the web frontend
allowed-tools: Bash, Read, Edit, Grep, Glob
---

# Run Frontend Lint

Run linting and formatting checks for the React/TypeScript frontend (`web`). All commands run
inside Docker.

## Usage

```bash
docker compose exec web yarn lint
docker compose exec web yarn format-check
```

To auto-fix formatting, run `docker compose exec web yarn format` instead of `format-check`.

## On Failure

If linting or formatting fails:
1. Review the errors reported
2. Fix the issues automatically using Edit tool when possible (or run `yarn format` for formatting)
3. Re-run the checks to verify fixes
