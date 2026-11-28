# Test Strategy (MVP)

| Status | Draft · v0.2 · 2026-11-24 · Owner: QA |
|---|---|

## Test levels
| Level | Who | Tooling |
|---|---|---|
| Unit / widget tests | Devs | `flutter test`, run in GitHub Actions on every PR |
| Database / RLS tests | Devs | SQL tests against Supabase local (`supabase start`) |
| Manual functional | QA | Test cases `TC-x.y.z` per story; each run is reported in `test-runs/<yyyy-mm-dd>-US-x.y-<platform>.md` |
| Location tests | QA | Mock GPS (Android dev options / emulator) for fixed Vũng Tàu points |
| Field test | QA + team | On-site in Vũng Tàu before beta (Sprint 4) — report in `field-tests/` |

## Device matrix (to confirm)
| Device | Why |
|---|---|
| Low-end Android (2–3 GB RAM) | Common among local users |
| Mid/high Android | Main target |
| iPhone Safari (Web build) | iOS users during beta |
| Desktop Chrome (Web build) | Owners managing lots |

## Test case naming
`TC-<epic>.<story>.<n>` e.g. `TC-6.2.1` — stored in `06-qa/test-cases/E<n>.md`, linked from the story.
Retired IDs (e.g. a case moved to another story) stay in the file marked "Retired → <new ID>" and are never reused.

| Epic | Test cases |
|---|---|
| E1 Location & Map | [test-cases/E1.md](test-cases/E1.md) |

## Fixed test locations (Vũng Tàu)
Mock GPS points `MP-n` are defined in SPEC-001 §8. **Entry criterion:** each point is verified against the local seed data (with supabase-dev) before the first test run that uses it.

| ID | Name | Purpose |
|---|---|---|
| MP-1 | Bãi Trước (Front Beach) | Default centre, dense area, tourists |
| MP-2 | Bãi Sau (Back Beach) | Dense area, many lots (clustering, 50 cap) |
| MP-3 | Tượng Chúa Kitô | Hilly, weaker GPS (low accuracy) |
| MP-4 | City center / market | Narrow streets |
| MP-5 | Offshore east of Bãi Sau | Empty within 1 km, lots within 3 km |
| MP-6 | HCMC District 1 | Outside service area |
| MP-7 | North-west corner of service area (10.4400, 107.0400) | Inside area, 0 lots within 3 km |
