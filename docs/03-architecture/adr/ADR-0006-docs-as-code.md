# ADR-0006: Documentation as code in the Git repo

- **Status:** Accepted
- **Date:** 2026-11-24
- **Decided in:** MTG-2026-11-24-kickoff

## Context
We must document design, meeting minutes and specs so we can trace decisions later and build future features on them. Tools must be free.

## Decision
- All docs are Markdown files under `docs/`, versioned in Git, changed via Pull Request.
- Every artifact has an ID (see [`docs/README.md`](../../README.md)); branches, commits and PRs reference story IDs.
- Jira Free tracks day-to-day status; the backlog content stays in sync with `docs/01-product/backlog.md`.

## Consequences
- Full history (who changed what, when, why) through Git.
- Docs reviewed like code; outdated docs are visible in PR diffs.
- Team must keep the habit: no decision without minutes/ADR.
