# ADR-0010: Enforce safety rules with Claude Code hooks

- **Status:** Accepted
- **Date:** 2026-11-24
- **Decided in:** Chat with PO Tan Dang, 2026-11-24 (Step 6 of the agentic setup)
- **Refines:** ADR-0008 (guardrails were instructions only)

## Context
Agents' folder and command limits (ADR-0008) were instructions, backed only by PR review. Some mistakes cannot be undone by review: changing or resetting the cloud database, pushing to `main`, force-pushing, skipping git hooks, reading secrets.

## Decision
A project-level `PreToolUse` hook (`.claude/settings.json` → `.claude/hooks/guard.js`, Node) checks every Bash/PowerShell/Read/Write/Edit call of the main agent **and all sub-agents**:

| Rule | Decision |
|---|---|
| `supabase … db reset --remote` | **deny** |
| Other `supabase … --remote` that change the cloud (e.g. `db push`, `migration repair`) | **ask** the human (intended path: `/deploy-db` after PR merge) |
| `--remote` read-only: `migration list`, `--dry-run`, `db diff/lint` | allow |
| `git push` to `main` (explicit or while on `main`), force-push | **deny** |
| `git … --no-verify` | **deny** |
| Read/Write/Edit or shell access to `.env*` (except `.env.example`) | **deny** |

The hook never blocks on its own errors (bad input → no decision).

## Consequences
- Rules are enforced technically, for every agent, regardless of its prompt.
- The hook is code: changes go through PR review; test cases are run by piping sample JSON (see `docs/05-process/ai-agents.md`).
- Pattern-based checks can be bypassed by unusual command forms; PR review and branch protection on GitHub remain the second line of defence. Recommended follow-up: enable GitHub branch protection on `main` (require PR).
- New team members get the hooks automatically when they pull the repo; a hook change needs a Claude Code restart (or `/hooks`) to load.
