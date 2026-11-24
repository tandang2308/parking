# ADR-0007: Database changes via Supabase CLI migrations

- **Status:** Accepted
- **Date:** 2026-11-24
- **Decided in:** Chat with PO, 2026-11-24 (Supabase project created)

## Context
The Supabase project exists (ref `kiqqlbxqhuenuahbrcbl`). Schema changes must be traceable and reviewable like code, and reproducible on a local database for development and tests.

## Options considered
| Option | Pros | Cons |
|---|---|---|
| **A. SQL migration files in `supabase/migrations/`, applied with Supabase CLI** | Versioned in Git, reviewed in PRs, same schema locally and in cloud | Team must learn the CLI |
| B. Edit tables directly in Supabase Studio | Easy | No history, no review, local and cloud drift apart |

## Decision
Option **A**. Every schema change is a new migration file (`supabase migration new <name>`), referenced to a story/spec, merged via PR, then applied with `supabase db push`. Supabase Studio is used for **data** (admin, ADR-0003), not for schema changes.

## Consequences
- Never edit an applied migration; add a new one.
- Secrets (DB password, service role key, access token) are never committed or pasted in chat; the CLI keeps them in the OS credential store.
- Local development: `supabase start` (needs Docker).
