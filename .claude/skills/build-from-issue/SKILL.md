---
name: build-from-issue
description: Take an accepted GitHub issue and implement it end-to-end, then open a PR that closes it
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
---

# Build from an issue

Turn an accepted issue into a reviewed-ready pull request, built to CardJoy's conventions. This is
the orchestration skill; it leans on [docs/DEVELOPMENT.md](../../../docs/DEVELOPMENT.md) and the
`add-graphql-mutation`, `add-frontend-page`, and `checks` skills.

Use this only for issues a maintainer has marked **accepted** / **ai-buildable** — i.e. small,
well-specified changes with clear acceptance criteria. If scope is unclear, ask for clarification on
the issue instead of guessing.

## Steps

1. **Read the issue.** Fetch it and its acceptance criteria:
   ```bash
   gh issue view <number>
   ```
   Restate, in your own words, what "done" means and which apps it touches (api / web / admin). If
   the acceptance criteria are ambiguous or too large for one PR, stop and comment on the issue.

2. **Orient in the code.** Read `CLAUDE.md`, `docs/ARCHITECTURE.md`, and the reference files named in
   `docs/DEVELOPMENT.md` for the layer(s) you'll touch. Find the closest existing feature and mirror
   it.

3. **Branch.**
   ```bash
   git checkout main && git pull
   git checkout -b feat/<short-name>
   ```

4. **Implement** against the acceptance criteria, following `docs/DEVELOPMENT.md`:
   - Backend changes → the `add-graphql-mutation` pattern (model/migration → mutation → type →
     register → factory → request spec).
   - Frontend changes → the `add-frontend-page` pattern (page → route → shadcn UI).
   - Add or update tests. Keep the change focused on the issue.

5. **Run every gate** with the `/checks` skill (or `make check`). Do not proceed until green;
   regenerate Sorbet RBIs if needed.

6. **Open the PR.** Fill in the PR template, include `Closes #<number>`, and describe how you
   verified each acceptance criterion.
   ```bash
   git push -u origin feat/<short-name>
   gh pr create --title "<type>(<scope>): <description>" --body "...Closes #<number>..."
   ```

7. **Hand off.** Summarize what changed and how it maps to the acceptance criteria. A maintainer
   reviews and merges — never merge your own AI-authored PR.

## Guardrails

- One logical change per PR; do not bundle unrelated fixes.
- Never commit secrets. This repo is public.
- Do not push to `main`; always go through a PR.
- If you can't satisfy an acceptance criterion, say so explicitly rather than marking it done.
