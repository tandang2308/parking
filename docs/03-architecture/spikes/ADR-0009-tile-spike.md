# Spike: ADR-0009 map tile rendering (OpenFreeMap vector tiles)

| Status | In progress — desk part done; **desktop Web checked by PO (§8)**; low-end Android + phone browser **pending (human)** · 2026-11-24 · Owner: flutter-dev |
|---|---|

- **For:** [ADR-0009](../adr/ADR-0009-map-tile-provider.md) "Validation gate (Sprint 1)" · action A6 in `docs/04-meetings/sprint-00/2026-11-24-po-decisions.md`
- **Branch:** `feature/US-1.1-app-skeleton`
- **Result (pass/fail):** not decided yet — the performance and rendering checks need a real low-end Android phone and browsers (see §5). Record the final result and measurements in the Sprint 1 review minutes (ADR-0009).

## 1. What was built
Flutter app skeleton in `app/` (`flutter create --org vn.parkfinder --project-name parkfinder --platforms android,web app`, Flutter 3.38.5 stable), only what the spike needs:

| File | Purpose |
|---|---|
| `app/lib/config/tile_config.dart` | Tile config from `--dart-define`: `TILE_STYLE_URL`, `TILE_RASTER_URL`, `TILE_ATTRIBUTION`, `TILE_MAX_ZOOM`, `TILE_RENDERER` (ADR-0009 decision 3) |
| `app/lib/features/map/base_tile_layer.dart` | The single vector↔raster switch: `buildBaseTileLayer(config)` → `VectorBaseLayer` (flutter_map_vector_tiles) or `RasterBaseLayer` (flutter_map `TileLayer`) |
| `app/lib/features/map/map_screen.dart` | Full-screen `FlutterMap`, centre 10.3460, 107.0740 (SPEC-001 BR-5), zoom 15, min 13, max from config (18) |
| `app/lib/features/map/map_attribution.dart` | Always-visible, wrapping attribution (SPEC-001 BR-13); text from config |
| `app/lib/features/map/map_constants.dart` | BR-5 centre and zoom constants |
| `app/test/*.dart` | Config unit tests + widget tests (no network) |
| `app/android/app/src/main/AndroidManifest.xml` | Added `INTERNET` permission (needed for tiles in release builds) |

Not built (out of spike scope): location, lots/pins, localisation setup (no user-facing strings yet besides the untranslated attribution), Supabase.

Design notes:
- The vector style (style.json, TileJSON, sprites, glyphs) is loaded once with `StyleReader(uri: TILE_STYLE_URL).read()`; until it is loaded the map background shows. The loader is injectable so tests never hit the network.
- flutter_map's `SimpleAttributionWidget` was **not** used: its single non-wrapping row overflowed in a 320 px-wide widget test. A small wrapping widget is used instead (tested at 320 × 640).
- In debug/profile builds the app logs `Map style loaded in <n> ms` (duration only, never coordinates — SPEC-001 BR-10).

## 2. Packages (all added as direct dependencies)
| Package | Version | Licence | Notes |
|---|---|---|---|
| `flutter_map` | 8.3.2 | BSD-3-Clause | Map widget, camera, gestures, raster `TileLayer` |
| `flutter_map_vector_tiles` | 2.12.0 | BSD-3-Clause | Requires flutter_map ≥ 8.2, Flutter ≥ 3.27; platforms incl. Android + Web. Chosen per ADR-0009; compatible, so `vector_map_tiles` was not needed |
| `latlong2` | 0.10.1 | Apache-2.0 | `LatLng` type |

New transitive packages: `dart_earcut` (MIT), `dart_polylabel2` (BSD-3), `mgrs_dart` / `proj4dart` / `wkt_parser` (MIT, via latlong2), `unicode` and `simple_sparse_list` (BSD-3), `uuid` (MIT), `http`, `intl` (BSD-3, Dart team), `path_provider` + platform implementations (BSD-3, Flutter team). A scan of the local pub cache found **no GPL/LGPL/AGPL licence** in the resolved dependency set. No paid services.

## 3. Attribution (closes ADR-0009 "To verify" 3; input for SPEC-001 BR-13 / TC-1.1.21)
Source: https://openfreemap.org, section "Attribution" (accessed 2026-11-24):

> If you are using alternative clients, or if you are using this in printed media or video, you must add the following attribution:
> OpenFreeMap © OpenMapTiles Data from OpenStreetMap
>
> You do not need to display the OpenFreeMap part, but it is nice if you do.

The HTML on that page links each part: "OpenFreeMap" → https://openfreemap.org, "© OpenMapTiles" → https://www.openmaptiles.org/, "OpenStreetMap" → https://www.openstreetmap.org/copyright. The TileJSON at https://tiles.openfreemap.org/planet carries the same text and links in its `attribution` field.

App default `TILE_ATTRIBUTION` = `OpenFreeMap © OpenMapTiles Data from OpenStreetMap` (plain text, not tappable — link behaviour is an open question, §7).

Also confirmed on the same page: "Is commercial usage allowed? Yes." (ADR-0009 "To verify" 4). The FAQ also limits offline/area downloads (≤ 3,000 tiles, ≤ 50 MB, ≤ 4 parallel requests, unique User-Agent) — we do no bulk prefetch (NFR-3a), so this does not apply.

## 4. Build and test results (this machine, Windows 11, Flutter 3.38.5)
| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | All 11 tests passed (config defaults/overrides/fallbacks, NFR-3a TTL ≥ 7 days, map centred on BR-5 at zoom 15 / min 13 / max 18, attribution visible + from config, no overflow at 320 px width, real `VectorTileLayer` mounts with an offline style, raster switch via config) |
| `flutter build web --release` | Succeeded (`build/web`; Wasm dry run also succeeded) |
| `flutter build apk --debug` | **Not run: no Android SDK on this machine** (`[!] No Android SDK found`). Not installed, per instructions |

Network checks with `curl` from the dev machine (desk checks, **not** a 4G measurement):
- Style `…/styles/liberty`, TileJSON `…/planet`, a z14 tile covering Vũng Tàu (`14/13065/7718`), and the Noto Sans glyph range 7680–7935 (Latin Extended Additional, where most Vietnamese letters with diacritics live) all return HTTP 200.
- Tiles are sent with `access-control-allow-origin: *` (CORS OK for Flutter Web) and `Cache-Control: max-age=315360000, public`.
- The Vũng Tàu z14 tile is ~100 KB and contains UTF-8 names with diacritics (e.g. "Bãi Trước", "Bãi Sau", "Thùy Vân", "Hạ Long", "Vũng Tàu"), so the **data** is right; whether the **renderer** draws them correctly must be checked on screen.
- The liberty style uses fonts "Noto Sans Regular/Bold/Italic" and also a small raster source (Natural Earth shaded relief, z ≤ 6 only — not fetched at our zoom 13–18).

## 5. Validation gate checklist (ADR-0009)
| # | Gate item | Status | Evidence / who |
|---|---|---|---|
| 1 | Code compiles; `liberty` style wired via config | **Verified here** | analyze + tests + web build (§4) |
| 2 | Flutter Web release build | **Verified here** | `flutter build web --release` succeeded |
| 3 | Android build | **NOT verified** — no Android SDK here | Human: `flutter build apk --debug` |
| 4 | Map widget + vector layer render in a widget test; attribution always visible | **Verified here** (offline style, no real tiles) | `app/test/map_screen_test.dart` |
| 5 | Config switch vector ↔ raster without code change | **Verified here** (widget/unit test) | `TILE_RENDERER=raster` test; real raster tiles not loaded in tests |
| 6 | Renders Vũng Tàu zoom 13–18 with `liberty` on a **low-end Android** device | **NEEDS A HUMAN** | §6 commands |
| 7 | Renders on **Flutter Web** (Chrome desktop + Chrome on a phone) | **NEEDS A HUMAN** | §6 commands |
| 8 | First tiles ≤ 3 s cold start on 4G (NFR-2) | **NEEDS A HUMAN** — not measured | §6 |
| 9 | No visible jank panning/zooming, ≥ 30 FPS on low-end Android in profile mode | **NEEDS A HUMAN** — not measured | §6 |
| 10 | Pins still ≤ 3 s on low-end (NFR-1) | **Cannot be tested yet** — no pins exist (US-1.2). Re-check when US-1.2 lands, or approximate by adding dummy markers during the device test | Human / later story |
| 11 | Vietnamese labels with diacritics render correctly | **NEEDS A HUMAN** (data and glyph range confirmed present, §4) | §6 |
| 12 | Caching meets NFR-3a (TTL ≥ 7 days, MIT/BSD, no bulk prefetch) | **Partly verified (config review)**: Android uses the package's built-in on-disk tile cache (BSD-3), TTL set to 14 days in `vectorTileDiskCacheTtl` (unit-tested ≥ 7 days), 50 MB cap; style bundle cached on disk too. Web: package has **no disk cache** — relies on the browser HTTP cache, and OpenFreeMap sends `max-age` ≈ 10 years. No prefetch is done. Runtime behaviour (offline reopen) **NEEDS A HUMAN** | config + §6 step 5 |

## 6. How to run the human checks
Prereqs: Flutter 3.38.x, Android SDK (Android Studio), a **low-end Android phone** with USB debugging, Chrome. From the repo root: `cd app`, then `flutter pub get`.

1. **Web (Chrome desktop):** `flutter run -d chrome` (look) and `flutter run -d chrome --profile` (performance). Or serve the release build: `flutter build web --release`, then serve `build/web` with any static server (e.g. `npx http-server build/web`) and open it in Chrome desktop and in Chrome on a phone on the same network.
2. **Android low-end:** `flutter devices` → `flutter run --profile -d <device-id>`. Always measure FPS in **profile** mode (debug is much slower and not representative).
3. **FPS / jank:** in the `flutter run` terminal press `P` to toggle the performance overlay (two graphs: UI and raster thread; red bars = frames over 16 ms). For numbers, open Flutter DevTools (URL printed by `flutter run`, or press `v`) → **Performance** tab → pan and zoom continuously between zoom 13 and 18 over Vũng Tàu for ~30 s → read the average FPS and the count of janky (red) frames. Pass: ≥ 30 FPS on the low-end phone, no visible stutter. For web, also use Chrome DevTools → Rendering → "Frame Rendering Stats".
4. **First tiles ≤ 3 s cold start on 4G:** phone on mobile data (4G, Wi-Fi off); clear app data (Settings → Apps → ParkFinder → Storage → Clear storage) so there is no cache; start a screen recording; launch the app; measure from the tap on the icon to the first visible map tiles. Repeat ≥ 5 times and note each value. The console also prints `Map style loaded in <n> ms` (profile/debug) as a partial figure. For web, use Chrome DevTools → Network → "Disable cache" + throttling "Fast 4G" (indicative only; a real 4G phone is the reference).
5. **Cache (NFR-3a):** after browsing the area once, enable airplane mode, restart the app, and check that the previously seen tiles still show.
6. **Vietnamese diacritics:** zoom to 16–18 around Bãi Trước / Bãi Sau and check street and place labels (e.g. "Thùy Vân", "Hạ Long", "Bãi Trước") show correct accents and no missing-glyph boxes — on Android and on web. Take screenshots for the review minutes.
7. **Raster fallback sanity check (dev only):** `flutter run -d chrome --dart-define=TILE_RENDERER=raster --dart-define=TILE_RASTER_URL=https://tile.openstreetmap.org/{z}/{x}/{y}.png "--dart-define=TILE_ATTRIBUTION=© OpenStreetMap contributors"` — OSM standard tiles are allowed for local development only (ADR-0009 decision 2).

Record for each device: model + Android version/RAM, browser, network, FPS, jank count, first-tile times, diacritics OK/not OK, screenshots.

## 7. Open questions
1. **Attribution link behaviour (BR-13):** OpenFreeMap's text contains three links. Should the attribution be tappable (needs `url_launcher`, BSD-3) or is plain text enough for the MVP? Currently plain text.
2. **Attribution must include "© OpenStreetMap contributors"?** SPEC-001 BR-13 says `"© OpenStreetMap contributors" + tile provider credit`, while OpenFreeMap's required text says "Data from OpenStreetMap". The current default follows OpenFreeMap's exact text; the spec owner should confirm whether to append/replace with "© OpenStreetMap contributors" (ODbL wording) and update BR-13 / TC-1.1.21.
3. **Web cache vs NFR-3a "on-device HTTP cache":** on web we rely on the browser HTTP cache (provider-controlled headers), not an app-controlled TTL. Acceptable for NFR-3a?
4. **Label language:** the liberty style shows `name:latin`/`name` (Vietnamese in Vũng Tàu). For the English UI, should labels switch to `name:en` (`StyleReader(language: 'en')`)? Not done.
5. **NFR-1 pins on low-end** cannot be checked before US-1.2; does the PO accept closing the gate with a dummy-marker test, or defer that item?

## 8. Human results

### 8.1 Desktop Web — Tan Dang (PO), 2026-11-24
Setup: Windows 11 PC, desktop Chrome, **debug** build via `flutter run -d web-server --web-port 8080` (opening Chrome automatically with `-d chrome` failed: "Failed to launch browser after 3 tries" — use `-d web-server` and open the URL manually). PC network, not 4G.

| Gate item (§5) | Result | Note |
|---|---|---|
| 7 Renders on Flutter Web (desktop Chrome) | **Pass** | Vũng Tàu map renders, zoom 13–18 |
| 11 Vietnamese diacritics on labels | **Acceptable** (PO) | Re-check on Android; report any specific broken names |
| 9 Smooth panning/zooming | **OK on desktop** | Desktop is much faster than a low-end phone — does **not** close the ≥ 30 FPS Android item |
| 4 Attribution always visible | **Pass** | "OpenFreeMap © OpenMapTiles Data from OpenStreetMap" visible |
| 8 First tiles time | **≈ 2 s** after full restart (indicative) | Debug build on PC network — not the NFR-2 4G cold-start measurement |

### 8.2 Still open before the gate can pass
- Low-end Android phone in profile mode: ≥ 30 FPS, first tiles ≤ 3 s on 4G, diacritics (needs Android SDK on a team PC + a phone; owner: QA / to assign).
- Chrome on a phone (Web build).
- Offline re-open with cached tiles (NFR-3a runtime).
