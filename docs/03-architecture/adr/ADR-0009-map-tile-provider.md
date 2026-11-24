# ADR-0009: Map tile provider for flutter_map (free for beta)

- **Status:** Accepted — conditional on the Sprint 1 validation spike (see "Validation gate"); if the spike fails, a new ADR supersedes this one with fallback 4a
- **Date:** 2026-11-24
- **Decided in:** MTG-2026-11-24-po-decisions (D8, D9) — accepted by PO Tan Dang; assumptions 4a, spike ≤ 1 day (flutter-dev) and ≥ 30 FPS confirmed
- **Deciders:** Tan Dang (PO), on Tech Lead proposal
- **Refines:** ADR-0002 (its "OSM tiles from a free plan (MapTiler or Stadia)" assumption). ADR-0002 stays Accepted and unchanged.
- **Closes when accepted:** kickoff A7 · MTG-2026-11-24-po-decisions A4 · SPEC-001 §9 Q3 · owns SPEC-001 NFR-3b

## Context
- ADR-0002 requires a $0 MVP and assumed "OSM tiles via MapTiler or Stadia free plan". Research (2026-11-24) shows both free plans are **non-commercial only**.
- Beta now is free (Android + Flutter Web, ~hundreds of weekly users), but the product is meant to earn money later (owners pay for featured listings, ADR-0004). A non-commercial plan would force a provider switch or a paid plan exactly at monetisation.
- Low-end Android is a key device (SPEC-001 NFR-1: pins ≤ 3 s on low-end; NFR-2: first tiles ≤ 3 s cold start on 4G).
- SPEC-001 NFR-3a: on-device tile cache, TTL ≥ 7 days, no bulk prefetch. NFR-3b: quota monitoring with 80% alert is owned by this ADR.
- Privacy (PDPL, CLAUDE.md): tiles must never carry the user's location. Note: every tile request inherently reveals the **viewed area** (z/x/y) and the client IP to the provider. Providers needing no API key and setting no cookies minimise linkability.

## Options considered
| | A. OpenFreeMap (public, vector) | B. MapTiler Cloud Free | C. Stadia Maps Free | D. OSM Foundation standard tiles |
|---|---|---|---|---|
| Cost | $0 | $0 | $0 (paid Starter ~US$20/mo — To verify) | $0 |
| Limits | None on views/requests; no SLA, may add fair-use limits later | ~5,000 sessions / ~100,000 requests per month (To verify); maps **suspended** for the rest of the month when hit | 200,000 credits/month; overage off by default (errors, no charge) | Limited donated capacity; may block without notice |
| Commercial use | **Allowed** (FAQ) | Non-commercial + R&D only | Non-commercial only (revenue product or for-profit = commercial) | Heavy use by a distributed consumer app forbidden |
| Tile type | Vector only (style e.g. `liberty`) | Raster + vector | Raster + vector | Raster |
| Client package | `flutter_map_vector_tiles` 2.9.x (BSD-3, flutter_map ≥ 8) or `vector_map_tiles` 8.0.0 (BSD-3) | `flutter_map` TileLayer (BSD-3) | `flutter_map` TileLayer (BSD-3) | `flutter_map` TileLayer (BSD-3) |
| Privacy | No key, no registration, no cookies | API key in URL (account-linked) | API key or domain auth (account-linked) | No key; must send identifying User-Agent/Referer |
| Performance risk | **Medium–high**: vector rendering may cause jank/low FPS on low-end Android and Web | Low (raster) | Low (raster) | Low (raster) |
| Bulk/offline prefetch | Allowed via self-hosting; public instance: be polite | Per ToS — To verify | Per ToS — To verify | Forbidden |
| Ops: quota monitoring (NFR-3b) | n/a (no quota) | Required (suspension risk) | Required | n/a, but blocking risk |

## Decision
1. **Primary: Option A — OpenFreeMap public instance, vector tiles**, rendered with `flutter_map_vector_tiles` (BSD-3-Clause). Only option that is $0, has no quota and permits the planned commercial use.
2. **Option D (OSM standard tiles) is allowed for local development only**, never in a distributed build.
3. **Configuration, not code:** tile/style URL, attribution text, max zoom and renderer type (vector/raster) live in one app config (e.g. `--dart-define` / config file). Switching provider must not need code changes beyond config, except vector↔raster which swaps the layer widget behind one abstraction.
4. **Fallback (in order)**, if the spike fails or the public instance becomes unreliable/limited:
   - a. Raster from Stadia or MapTiler **free plan for the closed, non-revenue beta only** (PO confirmed 2026-11-24, D9; provider terms still To verify), moving to their **paid plan** (~US$20/mo, needs a new ADR per ADR-0002) before any monetisation; or
   - b. Self-hosted OpenFreeMap / PMTiles extract of the Vũng Tàu region on free static hosting (cost and hosting choice — new ADR).

### Validation gate (Sprint 1)
A time-boxed technical spike in Sprint 1 (≤ 1 day, owner flutter-dev — PO confirmed, D9):
- Render Vũng Tàu at zoom 13–18 with the `liberty` style on a **low-end Android** device and **Flutter Web** (Chrome desktop + mobile).
- Pass: first tiles ≤ 3 s cold start on 4G (NFR-2); pins still ≤ 3 s on low-end (NFR-1); no visible jank when panning/zooming (target ≥ 30 FPS on low-end in profile mode — PO confirmed, D9); labels in Vietnamese render correctly (diacritics).
- Verify the caching approach meets NFR-3a with an MIT/BSD-licensed solution.
- If any check fails → write a new ADR that supersedes this one with fallback 4a. Record the spike result (pass/fail + measurements) in the Sprint 1 review minutes.

## Consequences
**Positive**
- $0 with no quota → no suspension risk and no NFR-3b monitoring needed for the primary option.
- Commercial use allowed → no forced switch at monetisation (ADR-0004).
- No API key in the client, no cookies → nothing secret to leak, lower linkability (PDPL).

**Negative / risks**
- No SLA; donation-funded; may introduce fair-use limits. Mitigated by config-based switching and fallbacks.
- Vector rendering cost on low-end Android / Web (mitigated by the spike gate).
- Extra dependency (`flutter_map_vector_tiles`) and styling work (fonts/sprites/glyphs also fetched from the provider).
- Tile requests still reveal viewed area + IP to the provider (true for every option); must be stated in the privacy notice (SPEC-005).

**Follow-ups** (done in the acceptance PR on 2026-11-24 unless marked open: SPEC-001 BR-13/NFR-3b/§9 Q3, architecture.md, PRD, CLAUDE.md, A7/A4 closed; **open:** exact attribution text, NFR-3a cache approach — both settled by the spike)
- SPEC-001 BR-13 / §6: exact attribution text, e.g. "OpenFreeMap © OpenMapTiles Data from OpenStreetMap" (To verify), plus link behaviour; update TC-1.1.21.
- SPEC-001 NFR-3a: caching approach for vector tiles (package built-in cache vs HTTP cache; avoid GPL packages such as `flutter_map_tile_caching` — licence To verify).
- SPEC-001 NFR-3b: mark "n/a for OpenFreeMap; required if fallback 4a is used (80% alert on provider dashboard)".
- SPEC-001 §9 Q3: mark resolved, link ADR-0009.
- `architecture.md` diagram and limits table ("OSM tiles (MapTiler/…)", "Monthly request quota") → OpenFreeMap; PRD risk row "tile quotas".
- CLAUDE.md stack line "`flutter_map` with OSM tiles" → "`flutter_map` + `flutter_map_vector_tiles`, OpenFreeMap vector tiles (OSM data)" — main agent/PO edit.
- Close kickoff A7 and po-decisions A4 in the next meeting minutes.

## To verify
1. MapTiler Free quotas (~5,000 sessions / ~100,000 requests per month) — secondary sources only.
2. Stadia paid Starter price (~US$20/month) and whether a closed, non-revenue beta counts as non-commercial.
3. OpenFreeMap exact attribution requirement (OpenFreeMap / © OpenMapTiles / © OpenStreetMap contributors).
4. OpenFreeMap current FAQ wording on commercial use and any fair-use limits at time of acceptance.
5. `flutter_map_vector_tiles` latest version, licence and compatibility with the flutter_map version we pin; Flutter Web support.
6. MapTiler/Stadia ToS on on-device caching TTL (relevant only for fallback 4a).

## Sources (accessed 2026-11-24)
- OSMF tile usage policy: https://operations.osmfoundation.org/policies/tiles/
- MapTiler terms: https://www.maptiler.com/cloud/terms/ · pricing: https://www.maptiler.com/cloud/pricing/ · sessions vs requests: https://docs.maptiler.com/guides/account/sessions-vs-requests/
- Stadia Maps pricing: https://stadiamaps.com/pricing/ · FAQ: https://stadiamaps.com/faqs/
- OpenFreeMap: https://openfreemap.org · https://github.com/hyperknot/openfreemap
- Packages: https://pub.dev/packages/flutter_map_vector_tiles · https://pub.dev/packages/vector_map_tiles
- Thunderforest guide (vector performance warning): https://www.thunderforest.com/articles/flutter-map-and-map-tiles-guide/
