# AI Agent Team

| Status | v0.1 · 2026-11-24 · Owner: Tech Lead · Ref: ADR-0008 |
|---|---|

Claude Code sub-agents defined in `.claude/agents/`. They **assist** the human team; humans stay accountable.

## Team
| Agent | Role | Writes to | Tools | Hard limits |
|---|---|---|---|---|
| `tech-lead` | Specs, ADRs, design reviews | `docs/` | Read, Grep, Glob, Write, Edit | No app code; scope = PO's decision |
| `supabase-dev` | Migrations, RLS, RPC, pgTAP tests, imports | `supabase/` | + Bash | Local DB only; never `--remote` / cloud |
| `flutter-dev` | Implement stories from specs + tests | app code | + Bash | Never changes specs; free, non-GPL packages only |
| `qa-engineer` | Test cases, reviews vs ACs, bug reports | `docs/06-qa/` | Read, Grep, Glob, Write, Edit | Never fixes code |
| `scrum-master` | Minutes, sprint docs, backlog consistency | `docs/` | Read, Grep, Glob, Write, Edit | Never invents decisions |

## How to use
- Ask Claude: *"Use the qa-engineer agent to write test cases for SPEC-001."*
- Manage agents: `/agents` command in Claude Code.

## Workflow and guardrails
1. Agents work on a branch and **do not commit**; the main agent reviews their output, then commits.
2. Every change goes through a **Pull Request**; the human PO (or the responsible human) approves and merges.
3. Cloud deploys (`supabase db push --remote`) only by the main agent after merge (ADR-0007).
4. Tool limits are enforced by the agent definition; folder and command limits are **instructions** — they are backed up by PR review, not by technical enforcement.
5. Agents start with no memory: the docs are their shared memory, so keep `docs/` and `CLAUDE.md` up to date.
