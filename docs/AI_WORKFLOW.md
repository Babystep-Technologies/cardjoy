# AI-assisted contribution workflow

Cardjoy is set up so that well-specified, accepted proposals can be built by an AI assistant
(Claude) and opened as a pull request for human review. This document describes that flow and how to
turn it on.

> **Status: scaffolded but inert.** The workflow (`.github/workflows/claude.yml`) exists but does
> nothing until a maintainer opts in (see [Enabling the assistant](#enabling-the-assistant)). Until
> then, labels and `@claude` mentions have no effect.

## End-to-end flow

```
  Issue filed (bug/feature form)
            │
            ▼
  Maintainer triages ──► labels `accepted`
            │
            ▼
  Maintainer adds `ai-buildable`  ────────────►  Claude Action builds it
            │                                     (branch, implement per docs +
            │                                      skills, run all quality gates)
            ▼                                              │
  (or `@claude` mention in a comment                       ▼
   for an interactive edit)                        Opens a PR: "Closes #<issue>"
                                                           │
                                                           ▼
                                        api/web/admin CI runs on the PR
                                                           │
                                                           ▼
                                        Maintainer reviews & merges
```

Key properties:

- **A human is always the gate.** Claude never merges its own PR; CI and a maintainer review every
  change, exactly like a human contribution.
- **Scope is bounded.** Auto-build is meant for small, well-specified issues (`ai-buildable`, often
  also `good first issue`). Larger features stay human-led.
- **The AI uses the same rules you do.** It follows `CLAUDE.md`, `docs/DEVELOPMENT.md`,
  `docs/ARCHITECTURE.md`, and the skills in `.claude/skills/` — so its PRs match the repo's
  conventions and pass the same gates.

## Two entry points

| Trigger | Who can use it | What happens |
|---------|----------------|--------------|
| Label an issue `ai-buildable` | Maintainers (only they can label) | Claude builds the issue via the `build-from-issue` skill and opens a PR. |
| Comment `@claude ...` on an issue/PR | Maintainers (OWNER/MEMBER/COLLABORATOR) | Claude responds or makes the requested edit interactively. |

## Writing an issue an AI can build

The feature-request form asks for **acceptance criteria** for exactly this reason. The clearer and
more concrete those criteria are, the better the result. Good issues:

- State the outcome as a checklist of verifiable behaviors.
- Name the area(s) affected (web / admin / api).
- Stay small enough to be one focused PR.

## Enabling the assistant

The workflow is inert by default. To turn it on:

1. **Install the Claude GitHub App** on the repository (grants the action permission to act on
   issues/PRs). See the setup instructions for
   [`anthropics/claude-code-action`](https://github.com/anthropics/claude-code-action).
2. **Add an authentication secret** in *Settings → Secrets and variables → Actions*:
   - `ANTHROPIC_API_KEY`, **or**
   - `CLAUDE_CODE_OAUTH_TOKEN` (if using OAuth — update `claude.yml` to use this input).
3. **Set the repo variable** `CLAUDE_ENABLED` to `true` in *Settings → Secrets and variables →
   Actions → Variables*.

To pause the assistant at any time, set `CLAUDE_ENABLED` back to `false` (or remove it) — no need to
delete the workflow.

## Safety notes

- Every job is gated on `CLAUDE_ENABLED == 'true'` **and** the presence of the auth secret, so a
  fork or a stranger cannot trigger it.
- The label trigger is inherently maintainer-only (only users with triage rights can apply labels).
- Comment triggers additionally require the commenter to be an `OWNER`, `MEMBER`, or `COLLABORATOR`.
- The workflow requests least-privilege permissions (contents/PRs/issues) and opens PRs rather than
  pushing to `main`.
