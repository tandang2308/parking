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
- Client: Flutter (Android + Web), `flutter_map` with OSM tiles
- Backend: Supabase (PostgreSQL + PostGIS, Auth, Storage, Row Level Security)
- Admin: Supabase Studio · CI: GitHub Actions · Beta: Firebase App Distribution
- Do not add paid services or dependencies without a new ADR.

## Traceability rules (mandatory)
- IDs: `E<n>` epic · `US-<e>.<n>` story · `SPEC-<nnn>` · `ADR-<nnnn>` · `MTG-<yyyy-mm-dd>-<type>` · `TC-<e>.<n>.<n>`
- Branch `feature/US-x.y-name` · Commit `US-x.y: message` (docs-only: `docs: message`)
- Every significant decision → new ADR (from `docs/templates/`). Never edit an Accepted ADR; supersede it.
- Behaviour or design changed → update the spec / architecture doc in the same PR.
- Never delete docs; mark them `Superseded` or `Deprecated`.

## Safety
- Never commit secrets (API keys, Supabase service key, tokens, `.env`). Only the Supabase `anon` key may be in the client.
- Location data is personal data (Vietnam PDPL): no server-side storage of user location unless a spec requires it.

## Commands
_To be added in Sprint 0 when the Flutter and Supabase projects are created._
