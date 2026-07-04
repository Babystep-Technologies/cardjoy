---
name: lint
description: Run linting and formatting for the web frontend
allowed-tools: Bash, Read, Edit, Grep, Glob
---

# Run Frontend Lint

Run linting and formatting checks for the React/TypeScript frontend. All commands run inside Docker.

## Usage

When invoked, run both format check and lint:

```bash
docker compose exec web yarn format
docker compose exec web yarn lint
```

## On Failure

If linting or formatting fails:
1. Review the errors reported
2. Fix the issues automatically using Edit tool when possible
3. Re-run the checks to verify fixes
