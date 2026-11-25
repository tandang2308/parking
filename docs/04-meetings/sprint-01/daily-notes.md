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
