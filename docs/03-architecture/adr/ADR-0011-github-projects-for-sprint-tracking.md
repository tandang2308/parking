# ADR-0011: Use GitHub Projects instead of Jira for sprint tracking

- **Status:** Accepted (PO Tan Dang, 2026-11-24, in chat)
- **Date:** 2026-11-24
- **Decided in:** MTG-2026-11-24-planning (D2)
- **Deciders:** Tan Dang (Product Owner) — accepted 2026-11-24
- **Supersedes (partly):** [ADR-0006](ADR-0006-docs-as-code.md) — only its line "Jira Free tracks day-to-day status; the backlog content stays in sync with `docs/01-product/backlog.md`". The rest of ADR-0006 (docs as code) stays valid.

## Context
- ADR-0006 planned Jira Free for day-to-day status. Kickoff actions A2/A3 (create a Jira board, import the backlog into Jira) were never done.
- In Sprint 1 Planning the PO decided to use GitHub Projects as the sprint board (MTG-2026-11-24-planning D2): <https://github.com/users/tandang2308/projects/1>, columns Todo / In Progress / Done.
- Sprint 1 items already exist as GitHub issues #16–#21 with labels `story`, `task`, `sprint-1`, `stretch`. Each issue links the SPEC-001 ACs, the E1 test cases and the Definition of Done. PRs close issues via `Closes #n`.
- The repo <https://github.com/tandang2308/parking> is public; code, PRs and docs already live on GitHub. The main agent can manage issues and the board with the `gh` CLI (`project` scope).
- The MVP must cost $0 ([ADR-0002](ADR-0002-zero-cost-mvp-stack.md)).

## Options considered
| Option | Pros | Cons |
|---|---|---|
| A. GitHub Projects + Issues | Same place as code, PRs and docs; native traceability story → issue → PR (`Closes #n`) → merge, no integration needed; main agent manages it with `gh` (no extra API token or tool); already set up and in use for Sprint 1; no extra account for the team | Fewer Scrum features out of the box than Jira (e.g. burndown/velocity reports — to verify); issues on a public repo are public, so content must stay non-sensitive; backlog.md and issues still duplicate titles/IDs |
| B. Jira Free (Atlassian Cloud), as ADR-0006 planned | Purpose-built Scrum tool (sprints, backlog, reports); familiar to many teams | Extra tool and accounts; linking to GitHub PRs needs an integration (GitHub for Jira app — availability/cost to verify); agents need a separate API token and tooling; board and import (A2/A3) still to be built; third copy of backlog content to sync; user limit of the free plan to verify |
| C. Docs only (`backlog.md`, no board) | Single source, zero duplication; fully versioned | No live status view; every status change needs a PR; no automatic close on merge; poor for Daily Scrum |

### Comparison
| Criterion | A. GitHub Projects | B. Jira Free | C. Docs only |
|---|---|---|---|
| Cost | $0 for current use (to verify limits) | $0 within free-plan limits (to verify) | $0 |
| Licence / terms | GitHub Terms of Service (already accepted for the repo) | Atlassian Cloud terms (new account) | none extra |
| Traceability story → issue → PR → merge | Native (`Closes #n`, linked PRs) | Via integration, key in branch/commit | Manual (IDs in commit messages only) |
| Effort for AI agents | Low — `gh issue`, `gh project` | Medium — separate API/token, new tool | Low — edit Markdown |
| Sync duplication with backlog.md | Titles/IDs/labels in issues | Titles/IDs/fields in Jira | None |
| Setup state | Done (board + #16–#21) | Not started | Exists |

### To verify (do not rely on until checked)
- Jira Free: current user limit and feature set (reports, automation), and the cost of the GitHub integration.
- GitHub Projects for a personal (user-owned) account: limits on items, fields, views, workflows/automation, and which Scrum features (iterations, charts) are free.
- Visibility: a user-owned project has its **own** visibility setting (public/private), independent of the public repo; issues on the public repo are public in any case. Project 1 is currently **private** (checked 2026-11-24 via `gh project view`); the team members need access, or the PO makes it public.

## Decision
We use **GitHub Projects + GitHub Issues** (option A) for day-to-day sprint tracking. This replaces only the Jira line of ADR-0006.

1. **Source of truth.** `docs/01-product/backlog.md` remains the source of truth for story **content** (IDs, titles, story points, spec links, priority). GitHub issues track **day-to-day status** only. If they disagree, backlog.md wins and the issue is fixed.
2. **One issue per item.** One issue per story or task in a sprint, title starting with the ID, e.g. `US-1.2: Nearby lots as pins`; tasks without a story ID start with `[Task]`, e.g. `[Task] ADR-0009 tile spike on low-end Android (A3)` (as issues #16, #17).
3. **Issue body.** Links the spec ACs, the related test cases (`TC-…`) and the Definition of Done ([`docs/05-process/scrum.md`](../../05-process/scrum.md)); no copied spec text beyond a summary.
4. **Labels.** `story` or `task`; one sprint label per sprint (`sprint-1`, `sprint-2`, …); `stretch` for stretch items.
5. **Board columns.** Todo / In Progress / Done on project 1.
6. **Who updates what.**
   - Developer (or the main agent on their behalf): moves the card to In Progress when starting; opens the PR with `Closes #n`.
   - Merge of the PR closes the issue → card goes to Done (built-in project workflow; to verify it is enabled).
   - Scrum Master: checks at Sprint Review that board, issues and backlog.md are consistent (IDs, SP, status), and creates the next sprint's issues/labels after Planning.
   - PO: accepts stories at Review; owns backlog.md content.
7. **Privacy (PDPL).** Issues, comments and the board are public. No personal data, user location data, secrets or keys in issues, comments, screenshots or logs.
8. **Sub-agents** do not create, edit or close issues; only the main agent uses `gh`, after the user's go-ahead (ADR-0008 rule that sub-agents do not touch the cloud).

## Consequences
**Positive**
- One platform for code, PRs, docs and status; traceability from story to merge is automatic.
- $0 and no new accounts or tokens; consistent with ADR-0002.
- AI agents can update status with the existing `gh` CLI.

**Negative**
- Fewer built-in Scrum reports than Jira; burndown/velocity may need to be computed manually from backlog.md (to verify what Projects offers).
- Status lives outside Git history (board state is not versioned in the repo).
- Small duplication remains (ID, title, labels in issues vs backlog.md); the SM consistency check at Review is needed.
- Everything in issues is public — the team must avoid sensitive content.

**Follow-up**
- PO: accept or reject this ADR; then update the ADR index status.
- ADR index: mark ADR-0006 "(Jira part superseded by ADR-0011)" — done as an index note; the ADR-0006 file itself stays unchanged.
- `docs/05-process/scrum.md`: checked on 2026-11-24 — it does not mention Jira or a board tool; no change needed. Optionally add a short "Board" line linking project 1 (PO to decide).
- `docs/01-product/backlog.md` already points to the GitHub Projects board — no change.
- `docs/01-product/roadmap.md` Sprint 0 row mentions Jira — historical, leave as is.
- Verify the items under "To verify" and record results in this ADR's PR or the next Sprint Review minutes.
