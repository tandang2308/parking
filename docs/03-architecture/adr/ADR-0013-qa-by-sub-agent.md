# ADR-0013: Manual QA runs are done by a QA sub-agent instead of a human tester

- **Status:** Accepted
- **Date:** 2026-11-26
- **Decided in:** Sprint 1 Daily Scrum 2026-11-26 (`docs/04-meetings/sprint-01/daily-notes.md`)
- **Deciders:** Tan Dang (PO)

## Context
Sprint 1 planning gave the human QA, TuyenCao, 8 person-days for Android and Web testing. TuyenCao was not available. On 2026-11-26 a Claude Code sub-agent ran the US-1.2 test cases on the Android emulator: it used `adb` for mock GPS, network on/off, taps, screenshots and logs. It produced a usable report (`docs/06-qa/test-runs/2026-11-26-US-1.2-android-emulator.md`) with 17 pass, 1 fail, 4 blocked and 12 not run, and found 1 bug plus 2 US-1.1 bugs. The existing `qa-engineer` agent (ADR-0008) can only read and write docs. It cannot run the app.

## Options considered
| Option | Pros | Cons |
|---|---|---|
| A. Wait for a human QA | Real device, real judgement (TalkBack, feel) | Blocks Sprint 1 Done; no QA available now |
| B. **QA sub-agent runs the manual test cases on the emulator and Web; humans cover what it can't** | Available now, repeatable, evidence for each result (logs, screenshots), $0 | Emulator only, no real low-end phone; can't inspect requests without a proxy; weak on accessibility and UX judgement; an AI tests AI-written code |
| C. The PO tests everything personally | Human judgement | PO time; not scalable |

## Decision
**Option B.** A new agent `qa-tester` (`.claude/agents/qa-tester.md`) runs the `TC-x.y.z` manual test cases on the Android emulator (`adb`) and on Web, and writes a test run report to `docs/06-qa/test-runs/`. It reports results and bugs; it never fixes code, commits, or touches the cloud. `qa-engineer` keeps writing test cases and reviewing against the ACs.
The main agent reviews every report (reproduces each Fail) before it is committed. **The PO accepts the story in the Sprint Review**, as before.
TuyenCao is no longer part of the Sprint 1 team.

## Consequences
- The DoD item "QA tested on Android (incl. a low-end device) and Web" is met by a `qa-tester` run on the emulator plus Web. **Open risk:** no real low-end device. Real-device checks are tracked separately (ADR-0009 tile spike #16, NFR-1 timing) and needed before beta.
- Cases the sub-agent cannot run (request inspection via proxy, TalkBack, real GPS behaviour) are listed as "Not run" in each report. The PO or Dev A runs them, or accepts the gap explicitly.
- Sprint 1 capacity drops by TuyenCao's 8 days; #16 has no owner (PO to reassign).
- Blocked cases that need QA seed data use a test build against the local Supabase (#33).
- `docs/05-process/ai-agents.md` lists the new agent. ADR-0008 stays valid (agents assist; humans stay accountable: the PO for acceptance, Dev A for code review).
