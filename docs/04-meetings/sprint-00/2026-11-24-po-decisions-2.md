# MTG-2026-11-24-po-decisions-2 — PO decisions after Sprint 0 parallel work (OSM data, QA questions, tile spike)

| Field | Value |
|---|---|
| Date / time | 2026-11-24 / _TBD_ |
| Type | Ad-hoc (async decision via chat) |
| Facilitator | Claude main agent |
| Note taker | Scrum Master agent |
| Attendees | Tan Dang (Product Owner), Claude main agent |
| Absent | Khoi Dang (Scrum Master) — async decision |

## Agenda
1. Review results of the Sprint 0 parallel work: PR #11 (E1 test cases v0.2), PR #12 (OSM import + QA seed), PR #13 (Flutter app skeleton + tile spike)
2. PO decisions on OSM data, QA open questions and map attribution
3. Android tester for the ADR-0009 validation gate

## Discussion summary
- Input: PRs #11 (E1 test cases v0.2), #12 (OSM import + QA seed) and #13 (Flutter app skeleton + ADR-0009 tile spike, desk part). The PO answered "agree all" to the proposals D1–D6.
- PO desktop Web spike results 2026-11-24: renders zoom 13–18, diacritics acceptable, smooth, attribution visible, ~2 s first load (debug build, PC network). Details in `docs/03-architecture/spikes/ADR-0009-tile-spike.md` §8 (in an open PR).
- Finding: some map labels show English names (Front Beach, Coconut Bay, Bau Sen Lake). Follow-up: set the style label language from the app locale in Sprint 1 (see A2).
- OSM import result (PR #12): only 40 lots, 37 unnamed, mostly tagged car — US-4.4 field survey gains priority (backlog note added).

## Decisions
| # | Decision | Ref (ADR / SPEC / US) |
|---|---|---|
| D1 | Load the 40 OSM parking lots (`supabase/data/osm_vung_tau.sql`) into the **cloud** database; the PO pastes the file into the Supabase Dashboard SQL Editor (data, not schema). The TEST seed (`supabase/seed.sql`) must never go to the cloud. | ADR-0003, US-4.1 |
| D2 | Customer-only lots (OSM `access=customers`) are kept and shown with a label (needs a spec/data follow-up, see A2). | SPEC-001, US-4.1 |
| D3 | Q-QA-30 confirmed: if consent is declined in the app, the app never calls location APIs, even if the OS permission was granted earlier. | SPEC-001, US-1.4 |
| D4 | Q-QA-32 accepted: on Web where storage is unavailable (Safari private mode) the consent screen may reappear every visit — acceptable for the beta. | SPEC-001, US-1.4 |
| D5 | Use OpenFreeMap's exact attribution text "OpenFreeMap © OpenMapTiles Data from OpenStreetMap"; Tech Lead updates SPEC-001 BR-13 and TC-1.1.21. | ADR-0009, SPEC-001 BR-13, TC-1.1.21 |
| D6 | Android tester for the ADR-0009 validation gate is TuyenCao (QA): needs the Android SDK on a team PC and a low-end Android phone; checks ≥ 30 FPS in profile mode, first tiles ≤ 3 s on 4G, diacritics. | ADR-0009, US-1.1 |

## Action items
| # | Action | Owner | Due | Status |
|---|---|---|---|---|
| A1 | Load OSM data (`supabase/data/osm_vung_tau.sql`) to the cloud DB via the SQL Editor (D1) | PO (Tan Dang) | Sprint 0 | Done (verified via cloud API 2026-11-24, MTG-2026-11-24-planning) |
| A2 | Update SPEC-001: BR-13 attribution (D5), customer-only label rule (D2), map label language from app locale | Tech Lead | Sprint 1 start | Open |
| A3 | Install the Android SDK and run the Android spike checks (D6) | TuyenCao (QA) | Sprint 1, first days | Open |
| A4 | Data-quality / survey plan for unnamed and car-only OSM lots, feeding US-4.4 | supabase-dev | Sprint 1 | Open |
| A5 | Resolve remaining Q-QA-24..32; update TC-1.1.21 to the D5 attribution text | QA with Tech Lead | Sprint 1 | Open |

## Open questions / parking lot
- Low-end Android phone and team PC for A3: which devices — _TBD_.
