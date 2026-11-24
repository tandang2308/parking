# CLAUDE.md — ParkFinder Vung Tau

Instructions for Claude Code and all sub-agents working in this repo. Keep this file short; details live in `docs/`.

## Project
Mobile/web app to find parking lots near the user's current position. Pilot city: Vũng Tàu (Vietnam).
Built with Scrum (2-week sprints). The human **Product Owner approves** all scope and decisions.

## Read before working
1. `docs/README.md` — doc structure and ID scheme
2. The relevant spec in `docs/02-specs/` and decisions in `docs/03-architecture/adr/`
3. `docs/05-process/scrum.md` — Definition of Ready / Done

## Tech stack (MVP must cost $0 — see ADR-0002)
- Client: Flutter (Android + Web), `flutter_map` + `flutter_map_vector_tiles` with OpenFreeMap vector tiles (OSM data, ADR-0009; tile URL/style in config, never hard-coded; tile.openstreetmap.org only for local dev)
- Backend: Supabase (PostgreSQL + PostGIS, Auth, Storage, Row Level Security)
- Admin: Supabase Studio · CI: GitHub Actions · Beta: Firebase App Distribution
- Do not add paid services or dependencies without a new ADR.

## Traceability rules (mandatory)
- IDs: `E<n>` epic · `US-<e>.<n>` story · `SPEC-<nnn>` · `ADR-<nnnn>` · `MTG-<yyyy-mm-dd>-<type>` · `TC-<e>.<n>.<n>`
- Branch `feature/US-x.y-name` · Commit `US-x.y: message` (docs-only: `docs: message`)
- Every significant decision → new ADR (from `docs/templates/`). Never edit an Accepted ADR; supersede it.
- Behaviour or design changed → update the spec / architecture doc in the same PR.
- Never delete docs; mark them `Superseded` or `Deprecated`.

## AI agent team
Role agents live in `.claude/agents/` (see `docs/05-process/ai-agents.md`, ADR-0008). Sub-agents never commit, push or touch the cloud; the main agent reviews their output first.
Skills (slash commands) live in `.claude/skills/`: `/minutes`, `/new-adr`, `/deploy-db` (see `docs/05-process/skills.md`). Cloud DB deploys only via `/deploy-db`.
People: PO = Tan Dang · Scrum Master = Khoi Dang.

## Safety
- Guardrail hook `.claude/hooks/guard.js` (ADR-0010) blocks: cloud DB reset, push to `main`, force-push, `--no-verify`, `.env` access; cloud DB changes need human confirmation. Don't try to work around it — if blocked, stop and tell the user.
- Never commit secrets (API keys, Supabase service key, tokens, `.env`). Only the Supabase `anon` key may be in the client.
- Location data is personal data (Vietnam PDPL): no server-side storage of user location unless a spec requires it.

## Commands
Supabase project ref: `kiqqlbxqhuenuahbrcbl`. Schema changes only via migrations (ADR-0007), never in Studio.
Every new table needs explicit `GRANT`s to `anon`/`authenticated` in its migration (cloud does not auto-grant; local does) plus RLS policies.
- `npx supabase migration new <name>` — new migration in `supabase/migrations/`
- `npx supabase start` / `stop` — local database (Docker; local ports are 553xx because Windows reserves 543xx)
- `npx supabase db reset` — rebuild local DB from migrations
- CLI defaults to the **local** DB. Cloud commands need `--remote`:
  `npx supabase db push --remote --dry-run` (preview), then `npx supabase db push --remote` (only after PR merge)

Flutter app lives in `app/` (Flutter 3.38 stable). Run from `app/`:
- `flutter analyze` and `flutter test` — both must pass before a PR (DoD)
- `flutter run -d chrome` (Web) · `flutter run --profile -d <device>` (Android, FPS checks)
- `flutter build web --release` · `flutter build apk --debug` (needs Android SDK)
- Tile config via `--dart-define` (`TILE_STYLE_URL`, `TILE_ATTRIBUTION`, `TILE_RENDERER`, …) — see `app/README.md`, ADR-0009
