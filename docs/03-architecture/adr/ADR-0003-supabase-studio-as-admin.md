# ADR-0003: Use Supabase Studio as admin panel for MVP

- **Status:** Accepted
- **Date:** 2026-11-24
- **Decided in:** MTG-2026-11-24-kickoff

## Context
Admins must manage lots and approve owner claims. Building a custom admin web app costs about one sprint.

## Decision
Use the built-in **Supabase Studio** table editor as the admin tool during MVP. Admin access limited to team members.

## Consequences
- Saves ~1 sprint.
- Less user-friendly; no custom workflows. Dedicated admin panel moved to post-MVP backlog (E10).
- Admin actions must still respect data rules (constraints/triggers in DB, not UI).
