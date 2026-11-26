# Sprint 1 — Daily Scrum notes

Only blockers, decisions and risks are recorded here (`docs/05-process/scrum.md`). Status lives on the board (GitHub Projects, ADR-0011).

## 2026-11-25 (Day 1)
Board: #18 US-1.4 Done · #19 US-1.1 Done (PR #26) · #20 US-1.2 In Progress, PR #27 awaiting review · #16, #17, #21 Todo. 8 / 16 SP done.

| # | Type | Item | Owner | Ref |
|---|---|---|---|---|
| 1 | Decision | Dev A reviews PR #27 (US-1.2) on 2026-11-26 | Dev A | #20 |
| 2 | Decision | QA runs the Android test cases on an **emulator**; the team has no physical Android device | TuyenCao | #16, #19, #20 |
| 3 | Risk | Emulator results are not representative for the ADR-0009 low-end Android tile spike (FPS / performance, #16) or for real GPS behaviour. Mitigation: use a low-spec AVD + mock locations; mark #16 results "emulator only" and re-check on a real device before beta | TuyenCao / PO | #16, ADR-0009 |
| 4 | Blocker (open) | The Android SDK / emulator is not installed on the dev PC, so `flutter build apk` has not run for US-1.1 / US-1.2 yet. Install Android Studio (free) with an AVD before Android QA | Dev A / QA | #19, #20 |

## 2026-11-26 (Day 2)
Board: #18, #19 Done · #20 US-1.2 In Progress, PR #27 awaiting Dev A review, Android QA run done · #17 In Progress (tech-lead agent draft, SPEC-001 v0.4) · #16, #21 Todo. 8 / 16 SP done.

| # | Type | Item | Owner | Ref |
|---|---|---|---|---|
| 1 | Blocker (resolved) | Day 1 #4 resolved: Android Studio + Pixel_6 emulator (API 35) installed; debug APK builds (Flutter uses JDK 21 — Gradle 8.14 does not run on the bundled Java 25; emulator storage moved to drive D:) | PO | #19, #20 |
| 2 | Decision | US-1.2 Android emulator run by the QA sub-agent for TuyenCao: 17 pass · 1 fail · 4 blocked · 12 not run — [report](../../06-qa/test-runs/2026-11-26-US-1.2-android-emulator.md) | QA | #20, PR #27 |
| 3 | Decision | BUG-1 (Expand → lots off screen, AC4 spec gap) is **not** fixed in PR #27; handled later | PO | #30 |
| 4 | Decision | US-1.1 findings logged as bugs; sprint vs backlog: **PO to decide** | PO | #31, #32 |
| 5 | Risk | 4 US-1.2 cases blocked: QA seed data exists only locally. Proposed: test build against local Supabase (no fake lots in cloud) — **PO to confirm** | PO / QA | #33 |
| 6 | Risk | Still not checked: request bodies via proxy (TC-1.2.9/.13/.20/.31), TalkBack (TC-1.2.22), real-device performance | TuyenCao / Dev A | #20, #16 |
| 7 | Risk | Drive C: on the dev PC has ~4 GB free — builds, emulator and OS updates may fail. Free up space | PO | — |
| 8 | Decision | Agents work on #17 (committed task) before stretch #21 | PO | #17, #21 |
