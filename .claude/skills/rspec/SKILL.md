---
name: rspec
description: Run rspec tests for the Rails backend
allowed-tools: Bash, Read, Grep, Glob
---

# Run RSpec Tests

Run rspec tests for the Rails API backend. All commands run inside Docker.

## Usage

When invoked with arguments, run those specific tests:
- `/rspec spec/models/user_spec.rb` - Run a specific file
- `/rspec spec/models/` - Run all specs in a directory
- `/rspec spec/models/user_spec.rb:42` - Run a specific line

When invoked without arguments, determine which tests to run based on context:
1. If there are uncommitted changes to spec files, run those specs
2. If there are uncommitted changes to source files, find and run related specs
3. Otherwise, ask the user which tests to run

## Command

```bash
docker compose exec api bundle exec rspec <args>
```

## On Failure

If tests fail:
1. Read the failing test file to understand the test
2. Read the relevant source code
3. Explain the failure and suggest fixes
