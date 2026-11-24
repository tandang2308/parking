# Test Strategy (MVP)

| Status | Draft · v0.1 · 2026-11-24 · Owner: QA |
|---|---|

## Test levels
| Level | Who | Tooling |
|---|---|---|
| Unit / widget tests | Devs | `flutter test`, run in GitHub Actions on every PR |
| Database / RLS tests | Devs | SQL tests against Supabase local (`supabase start`) |
| Manual functional | QA | Test cases `TC-x.y.z` per story |
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

| Epic | Test cases |
|---|---|
| E1 Location & Map | [test-cases/E1.md](test-cases/E1.md) |

## Fixed test locations (Vũng Tàu)
| Name | Purpose |
|---|---|
| Bãi Sau (Back Beach) | Dense area, many lots |
| Bãi Trước (Front Beach) | Dense area, tourists |
| Tượng Chúa Kitô | Hilly, weaker GPS |
| City center / market | Narrow streets |
