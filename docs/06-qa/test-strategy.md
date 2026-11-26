# Test Strategy (MVP)

| Status | Draft · v0.2 · 2026-11-24 · Owner: QA |
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

## Test data: local QA build (#33)
The cloud database holds only real lots; the QA seed (`supabase/seed.sql`: ≥ 60 lots at MP-2, motorbike/car mix, identical-coordinate pair) exists **only locally** and must never be loaded into the cloud. Cases that need it (e.g. TC-1.2.6, .16, .21 `hint_cap`, .30) run against a **debug** build pointed at the local Supabase:
1. Start Docker Desktop, then `npx supabase start` (from the repo root). Check: `nearby_lots(10.3440, 107.0960, 1000)` returns 50 rows.
2. Settings file **outside the repo**, e.g. `D:\Projects\parking-local\supabase.local.json`: `{ "SUPABASE_URL": "http://127.0.0.1:55321", "SUPABASE_ANON_KEY": "<local anon key from npx supabase status>" }` (the local demo key, not the cloud key).
3. Android emulator: `adb reverse tcp:55321 tcp:55321` (after every emulator start), then `flutter build apk --debug --dart-define-from-file=D:\Projects\parking-local\supabase.local.json` and `adb install -r build\app\outputs\flutter-apk\app-debug.apk`. Plain `http` is allowed in **debug builds only** (`app/android/app/src/debug/AndroidManifest.xml`).
4. Web: `flutter run -d web-server --web-port 8080 --dart-define-from-file=D:\Projects\parking-local\supabase.local.json`.
The test run report states which backend was used ("cloud" or "local seed").
