# MTG-2026-11-24-po-decisions — PO decisions on QA open questions (SPEC-001)

| Field | Value |
|---|---|
| Date / time | 2026-11-24 / _TBD_ |
| Type | Ad-hoc (async decision via chat) |
| Facilitator | Claude main agent |
| Note taker | Scrum Master agent |
| Attendees | Tan Dang (Product Owner), Claude main agent |
| Absent | _TBD_ |

## Agenda
1. Review QA open questions Q-QA-1..23 (`docs/06-qa/test-cases/E1.md`, SPEC-001 §9)
2. PO decisions on the questions needing product input
3. Delegation of the remaining questions

## Discussion summary
- Input: QA open questions Q-QA-1..23 in [E1 test cases](../../06-qa/test-cases/E1.md) and [SPEC-001](../../02-specs/SPEC-001-location-and-map.md) §9, raised by the qa-engineer and supabase-dev agent runs (PR #5 merged).
- Six questions needed a PO decision; the PO approved all six proposals ("agree all 6").
- The other 17 QA questions are delegated to the Tech Lead, who resolves them in SPEC-001 v0.2; the PO approves them via the PR.

## Decisions
| # | Decision | Ref (ADR / SPEC / US) |
|---|---|---|
| D1 | Minimal location consent screen S1 moves into Sprint 1 as new story **US-1.4** "As a driver, I want to be asked for consent before the app uses my location, so that my personal data is protected (PDPL)" — part of E1, est. 3 SP (to be re-estimated by the team). Full privacy policy stays in US-5.2 (Sprint 3). | SPEC-001 v0.2, US-1.4, US-5.2 |
| D2 | Tech Lead drafts the Vietnamese texts for all missing UI strings; PO reviews the vi wording. | SPEC-001 §6 |
| D3 | Distance format: < 1 km → metres rounded to 10 m ("350 m"); ≥ 1 km → km with one decimal ("1.2 km"). | SPEC-001 v0.2, US-1.2 |
| D4 | User outside Vũng Tàu → lots shown around the Vũng Tàu default centre with the out-of-area banner. | SPEC-001 v0.2 |
| D5 | Each new search starts at 1 km; "Expand to 3 km" applies only to the current search. | SPEC-001 v0.2, US-1.2 |
| D6 | Low-accuracy banner is dismissible; it does not come back for the rest of the session. | SPEC-001 v0.2 |
| D7 | Remaining 17 QA questions delegated to the Tech Lead, resolved in SPEC-001 v0.2; PO approves via the PR. | SPEC-001 v0.2 |
| D8 | *(Addendum, later on 2026-11-24)* ADR-0009 accepted: OpenFreeMap public vector tiles via `flutter_map_vector_tiles`, tile URL/style as config — **conditional on a Sprint 1 validation spike**; if it fails, a new ADR supersedes it with fallback 4a. | ADR-0009 |
| D9 | *(Addendum)* PO confirmed ADR-0009 assumptions: fallback 4a (Stadia/MapTiler free plan) acceptable only for the closed, non-revenue beta; spike time-box ≤ 1 day, owner flutter-dev; smoothness target ≥ 30 FPS on low-end Android. | ADR-0009 |

## Action items
| # | Action | Owner | Due | Status |
|---|---|---|---|---|
| A1 | Update SPEC-001 to v0.2 with D1–D6 and resolve remaining Q-QA items | Tech Lead | 2026-11-24 | Done (PR #6 merged) |
| A2 | Review Vietnamese strings in SPEC-001 §6 and approve the v0.2 PR | PO | Sprint 0 | Done (PR #6 merged by PO) |
| A3 | Update `docs/06-qa/test-cases/E1.md` to SPEC-001 v0.2 (US-1.4 cases, resolved questions) | QA | Sprint 0 | Open |
| A4 | Tile provider decision as an ADR (kickoff action A7, still open) | Tech Lead | Before Sprint 1 | Done (ADR-0009, D8) |
| A6 | *(Addendum)* Tile rendering spike per ADR-0009 validation gate (≤ 1 day); record result in Sprint 1 review | flutter-dev | Sprint 1 | Open |
| A5 | QA seed data incl. a point with 0 lots within 3 km (Q-QA-3) | supabase-dev | Sprint 1 | Open |

## Open questions / parking lot
- Product Owner name: Tan Dang (resolved 2026-11-24; kickoff action A1 partly done — Scrum Master still open).
