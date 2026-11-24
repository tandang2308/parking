---
name: deploy-db
description: Safely apply merged Supabase migrations to the cloud project kiqqlbxqhuenuahbrcbl and verify them through the real API. Only run when the user explicitly invokes /deploy-db.
disable-model-invocation: true
---

# /deploy-db — deploy database migrations to the cloud

Procedure from ADR-0007, including the lessons learned on 2026-11-24 (local auto-grants hid a cloud permission bug). Stop and report at the first failing step — never "fix forward" in the cloud.

## 1. Preconditions
- `git fetch origin`; switch to `main` and `git pull --ff-only`. Refuse if the working tree is dirty or `main` is not equal to `origin/main` — only **merged** migrations are deployed.
- `supabase/.temp/project-ref` must be `kiqqlbxqhuenuahbrcbl` (else ask the user to run `npx supabase link --project-ref kiqqlbxqhuenuahbrcbl` in their own terminal).

## 2. Test locally first
- Docker running → `npx supabase db reset` then `npx supabase test db`. All tests must pass. If Docker is not running, ask the user to start Docker Desktop.

## 3. Preview
- `npx supabase db push --remote --dry-run` and show the user the list of migrations that would be applied.
- If the list is empty → report "already up to date" and stop.
- **Ask the user to confirm** before continuing.

## 4. Apply
- `npx supabase db push --remote --yes`, then `npx supabase migration list --remote` → local and remote must match.

## 5. Verify through the cloud API (as the app would)
- Get **only** the anon key, never print other keys:
  `npx supabase projects api-keys --project-ref kiqqlbxqhuenuahbrcbl -o json` piped to a filter that keeps the `anon` entry only.
- With `https://kiqqlbxqhuenuahbrcbl.supabase.co/rest/v1`:
  - each RPC touched by the new migrations is callable by anon (expect 200, e.g. `nearby_lots` → JSON array),
  - each table touched: anon `SELECT` allowed where the spec says so, anon `INSERT` → `42501`.
- Any unexpected `42501` on read = missing `GRANT` → write a **new** migration on a `fix/` branch; never edit an applied one.

## 6. Report
Table: step → result. Mention which migrations were deployed. Never print secrets (service_role key, DB password, tokens).
