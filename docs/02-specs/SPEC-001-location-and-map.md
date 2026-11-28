# SPEC-001: Location & Map

| Field | Value |
|---|---|
| Epic | E1 |
| Status | Draft |
| Version | 0.4 |
| Author | Tech Lead (with PO) |
| Reviewers | PO, Tech Lead, QA |
| Last updated | 2026-11-28 |
| Related | ADR-0002, MTG-2026-11-24-kickoff, MTG-2026-11-24-po-decisions, US-1.1, US-1.2, US-1.3, US-1.4 · depends on US-4.1 (lot data) · full privacy policy content and i18n framework: US-5.2 / SPEC-005 (S1 consent itself is US-1.4, Sprint 1 — D1) |

Decisions marked **(Dn)** are PO decisions from MTG-2026-11-24-po-decisions. Items marked *(Tech Lead decision — PO approves via PR)* resolve QA questions Q-QA-n (see §9 "Resolved questions").

## 1. Goal
Deliver the core of the vision: *"Open the app, see the nearest suitable parking lot."* A driver (tourist by car or local on a motorbike) opens ParkFinder in Vũng Tàu and immediately sees **where they are** and **which parking lots are around them**, even when GPS is weak or location is not shared — and is asked for consent before the app uses their location (PDPL).
E1 is the entry screen of Driver mode. It hands off to E2 (filters/list), E3 (lot details) and E6 (verified badge/availability).
Sprint goal link: Sprint 1 — *"A user can open the app and see their location + nearby lots on the map."*

## 2. User stories & acceptance criteria
All user-facing strings below have a key in §6 (D2).

### US-1.4 — Consent before using my location (D1)
**As a** driver, **I want** to be asked for consent before the app uses my location, **so that** my personal data is protected (PDPL).

- **AC1 (consent first):** Given a first launch, when the app opens, then the in-app consent screen S1 is shown **before** any OS/browser permission prompt, and no location API (incl. last-known position) is called before the user taps "Allow". *(moved from US-1.1 AC1)*
- **AC2 (content):** Given S1 is shown, then it shows `consent_title`, `consent_body` (purpose: show nearby lots; used only while the app is open; not stored on our servers; can be turned off in device/browser settings) and the buttons "Allow" / "Not now". A "Privacy policy" link is shown only once the policy page from US-5.2 exists; until then `consent_body` is the minimal notice. *(Tech Lead decision — PO approves via PR; see §9 Q-B)*
- **AC3 (allow):** Given S1, when the user taps "Allow", then the consent result (`granted`, consent version, timestamp) is stored on the device and the OS/browser permission is requested (continues in US-1.1 AC2/AC4/AC5).
- **AC4 (not now):** Given S1, when the user taps "Not now", then the result `declined` is stored on the device, no OS/browser prompt appears, and the map opens (US-1.1 AC3). The app is never blocked.
- **AC5 (no nagging):** Given consent was declined, when the app is relaunched, then S1 is **not** shown automatically again (same consent version); it is reopened only via the "Enable" action (US-1.1 AC3). *(Tech Lead decision — PO approves via PR)*
- **AC6 (version change):** Given a stored consent with an older consent version, when the app opens, then S1 is shown again before any location API call.
- **AC7 (device only):** Given any consent result, then it is stored only on the device (Android SharedPreferences / Web localStorage) and **no** network request carries it (BR-9). Clearing app data / site data shows S1 again on next launch.
- **AC8 (withdrawal via OS):** Given consent was granted, when the user later revokes the OS/browser permission, then the app behaves as US-1.1 AC4/AC5 without crashing. An in-app "withdraw consent" setting is not part of this story (see §9 Q-C).

### US-1.1 — See my current position on a map
**As a** driver, **I want** to see my current position on a map, **so that** I can orient myself and find parking around me.

- **AC1 (consent gate):** Moved to **US-1.4 AC1**. US-1.1 starts only after "Allow" on S1; otherwise AC3 applies.
- **AC2 (granted):** Given the user accepts consent and grants permission, when a position fix arrives, then the map centres on the user at zoom 16 with a blue dot and an accuracy circle (radius = reported accuracy), and **follow mode is on** (Q-QA-7). *(Tech Lead decision — PO approves via PR)*
- **AC3 (declined in-app):** Given the user taps "Not now" on S1 (US-1.4 AC4), when the map opens, then no OS prompt appears, the map is centred on the default centre (BR-5), and the banner `banner_location_needed` "Turn on location to see lots near you" with "Enable" is shown; "Enable" reopens S1.
- **AC4 (denied once):** Given the OS/browser prompt is denied, when the map opens, then behaviour equals AC3 and "Enable" re-requests the permission.
- **AC5 (denied forever / blocked):** Given Android "Don't ask again" or Web site permission "Blocked", when the user taps "Enable", then Android opens the app settings page; Web shows the unblock guide (`web_unblock_title` / `web_unblock_guide`). On return to the app with permission granted, the blue dot appears without restart. Android cannot report "blocked" before a request, so the app remembers on the device (a flag only, no location data) that the last request ended as "Don't ask again"; after a relaunch the **first** "Enable" tap opens the app settings (#32).
  - Web detection (Q-QA-22): the app does **not** rely on the Permissions API (limited on iPhone Safari). "Enable" calls the Geolocation API once; if it returns `PERMISSION_DENIED`, the unblock guide is shown. The Permissions API may be used only as an optimisation where supported. *(Tech Lead decision — PO approves via PR)*
- **AC6 (GPS off — Android only):** Given permission is granted but device location services are off, when the map opens, then the banner "Location is off" with "Turn on" is shown and "Turn on" opens the Android location settings. When the user returns with location on, the app gets a fix within 5 s **measured from the app returning to the foreground**, without restart (Q-QA-4). On Web, location-off is not detectable and is handled as a timeout (AC9); no "Turn on" action is shown on Web (Q-QA-5). A declined Google Play services "Location Accuracy" dialog while device location is **on** is not "location off": it is handled as AC9 (timeout → last-known or `banner_no_fix`) (#31). *(Tech Lead decision — PO approves via PR)*
- **AC7 (movement):** Given the map is showing the user, when the user moves ≥ 10 m, then the blue dot moves. The camera follows only while follow mode is on. Follow mode is on after the first fix (AC2) and after tapping "My location"; it switches off when the user pans.
- **AC8 (recenter):** Given the user has panned away, when they tap the "My location" button, then the map animates back to the current position at zoom 16, follow mode turns on, and a new search starts at 1 km (BR-3 (b), D5).
- **AC9 (timeout):** Given no fix within 10 s after permission is granted, when a last-known position < 5 min old exists, then it is shown with the hint "Locating…" and lots are loaded around it; otherwise the default centre is used and the banner `banner_no_fix` "Can't get your location — adjust manually?" with "Adjust" is shown ("Adjust" starts adjust mode, US-1.3 AC2). Last-known position is used on **Android only**; Web has no last-known API and goes straight to the default centre (Q-QA-8). *(Tech Lead decision — PO approves via PR)*
- **AC10 (outside service area):** Given the user's position is outside the service area (BR-12), when the fix arrives, then the blue dot is shown at the user's position, lots are loaded around the default centre (BR-14, **D4**), and the banner "ParkFinder currently covers Vũng Tàu only" with "Go to Vũng Tàu" is shown; "Go to Vũng Tàu" moves the camera to the default centre (zoom 15) and turns follow mode off. The banner has a close (×) action and, once closed, does not reappear for the rest of the session. *(close action: Tech Lead decision, consistent with D6 — PO approves via PR)*
- **AC11 (Web):** Given the Web build on HTTPS, when the user grants browser geolocation, then AC2–AC10 behave the same (except AC6 and the last-known part of AC9, see above). If the Geolocation API is unavailable (non-HTTPS or unsupported), the app behaves as in AC3 without errors.
- **AC12 (late fix, new):** Given the timeout path of AC9 was taken, when a GPS fix arrives later, then: if the user has not panned and no manual position is set, it is handled as the first fix (AC2: camera to the fix at zoom 16, follow on, new 1 km search, `banner_no_fix` / "Locating…" removed); otherwise only the blue dot appears (no camera jump, no reload; the user can tap "My location"). When a fresh fix replaces a last-known position, lots are reloaded once only if the fix is > 100 m from the last search centre (Q-QA-8). *(Tech Lead decision — PO approves via PR)*

### US-1.2 — See nearby parking lots as pins
**As a** driver, **I want** to see nearby parking lots as pins on the map, **so that** I can quickly pick the closest suitable one.

- **AC1 (initial load):** Given a position (GPS, last-known, manual or default centre), when the map opens, then `nearby_lots` is called with the search point (BR-14) and `radius_m = 1000`, and pins appear within 2 s on 4G (NFR-1).
- **AC2 (pin style):** Given lots are returned, then each pin shows the icon for its vehicle types: motorbike, car, or both (BR-6).
- **AC3 (loading):** Given a request is in flight, then a non-blocking progress indicator is visible, the map stays pannable/zoomable, and the previous pins stay visible until the response arrives.
- **AC4 (empty):** Given a position-based search (BR-3 (a)–(c)) returns 0 lots, then `empty_radius` "No parking lots within 1 km" is shown with "Expand to 3 km"; after expanding, the same search is repeated with `radius_m = 3000`. If still 0, `empty_none` "No parking lots found nearby yet" is shown with no further action. **Every new search trigger starts again at 1 km; "Expand" applies only to the current search (D5).** Given a "Search this area" search returns 0 lots, then `empty_area` "No parking lots in this area" is shown with **no** Expand action (the user zooms out and searches again) (Q-QA-10). *(area-search empty state: Tech Lead decision — PO approves via PR)*
- **AC5 (error/offline):** Given the request fails or there is no internet, then the banner "Can't load parking lots" + "Retry" is shown, existing pins are kept, and no crash or blank screen occurs. "Retry" repeats the last request (same point and radius). Automatic retry (Q-QA-11): exactly **one** automatic retry when connectivity changes from offline to online (Web: the browser `online` event); never on HTTP/server errors; if that retry fails, the banner stays and only manual "Retry" remains. *(Tech Lead decision — PO approves via PR)*
- **AC6 (search this area):** Given the user pans or zooms beyond BR-3's threshold, then a "Search this area" button appears; when tapped, lots are loaded around the map centre (radius per BR-3) and the button hides. Lots are **never** reloaded automatically on pan/zoom.
- **AC7 (clustering):** Given ≥ 2 pins overlap on screen (BR-4), then they are shown as one cluster with a count; tapping the cluster zooms in until the pins separate. Pins that cannot separate at the maximum zoom (identical/near-identical coordinates) are spiderfied (fanned out) on tap so each one can be selected (Q-QA-13). *(Tech Lead decision — PO approves via PR)*
- **AC8 (tap pin → hand-off):** Given pins are shown, when the user taps a pin, then it is highlighted and a mini card shows name, vehicle types, the "Customers only" label for customer-only lots (BR-16, v0.4) and the distance from the user's current position (BR-11) formatted per **BR-15 (D3)** — the distance is **hidden** when there is no user position (BR-11, v0.3 D7); tapping the card opens the lot detail screen (SPEC-003, US-3.1). Out of scope here beyond navigation to route `/lot/:id`.
- **AC9 (cap):** Given the RPC returns exactly 50 lots (the BR-2 maximum), then the hint "Showing nearest 50 — zoom in to see more" is shown. Exactly 50 lots in radius also shows the hint; this is accepted (Q-QA-14). *(Tech Lead decision — PO approves via PR)*
- **AC10 (no location):** Given location is unavailable (US-1.1 AC3/AC4/AC5/AC9 without last-known), then lots are still loaded around the default centre.
- **AC11 (outside service area, new — D4):** Given the current position (GPS or manual) is outside the service area, when a position-based search is triggered, then the search point is the default centre (BR-14), and card distances are still computed from the user's position (BR-11; may be large, e.g. "95.3 km").

### US-1.3 — Adjust my position manually
**As a** driver, **I want** to adjust my position manually when GPS is inaccurate, **so that** the nearby lots and distances are correct for where I really am.

- **AC1 (low-accuracy prompt):** Given a fix with low accuracy (BR-7), then the banner "Your location may be inaccurate" with "Adjust" and a close (×) action is shown. **Once closed, it does not reappear for the rest of the session** (until app restart / page reload), even on new low-accuracy fixes (**D6**).
- **AC2 (enter adjust mode):** Given the map screen, when the user taps "Adjust" (low-accuracy banner, or the `banner_no_fix` banner of US-1.1 AC9), or the overflow menu item "Set my position", or long-presses the map, then adjust mode starts: a crosshair pin fixed at the screen centre, the hint "Move the map to your exact position", and "Confirm" / "Cancel" buttons. On long-press, the map animates so the pressed point sits under the crosshair. A long-press while already in adjust mode does the same (moves the pressed point under the crosshair) (Q-QA-17). *(Tech Lead decision — PO approves via PR)*
- **AC3 (confirm):** When the user taps "Confirm", then the manual position replaces the blue dot with the "manual" marker style, a new search starts at 1 km around it (BR-3 (c), D5, BR-14), and card distances are computed from it.
- **AC4 (GPS ignored while manual):** Given a manual position is active, when new GPS fixes arrive, then the position does not change. Tapping "My location" switches back to GPS (toast "Using GPS location") **only if** permission is granted and location services are on; otherwise the manual position stays active and "My location" runs the same action as the current banner ("Enable" → US-1.1 AC3–AC5, "Turn on" → AC6) (Q-QA-18). If GPS is switched to but no fix arrives within 10 s, US-1.1 AC9 applies. *(Tech Lead decision — PO approves via PR)*
- **AC5 (cancel):** When the user taps "Cancel", then the previous position and pins are unchanged and no request is sent.
- **AC6 (no GPS needed):** Given location permission is denied or GPS is off, then the user can still set a manual position and get nearby lots.
- **AC7 (privacy):** Given a manual position, then it is kept in memory only (cleared on app restart / page reload) and is sent to the server only as RPC parameters (BR-10). Session-only is final for the MVP (spec §9 item 6, PDPL data minimisation). *(Tech Lead decision — PO approves via PR)*
- **AC8 (manual outside area, new):** Given a manual position outside the service area is confirmed, then US-1.1 AC10 / US-1.2 AC11 apply (out-of-area banner, lots around the default centre) (Q-QA-18). *(Tech Lead decision, consistent with D4 — PO approves via PR)*

## 3. UX / UI
Figma: _TBD — required before stories are Ready (DoR)._

| Screen / element | Description |
|---|---|
| S1 Consent screen (US-1.4) | Title, minimal notice (`consent_body`), buttons "Allow" / "Not now"; "Privacy policy" link once US-5.2 delivers it. Shown on first launch, again if the consent version changes, and via "Enable" after a decline. |
| S2 Map screen | Full-screen `flutter_map` (max zoom 18); blue dot + accuracy circle; "My location" FAB; "Search this area" chip (top centre); banner area (top); lot mini card (bottom); tile attribution (bottom-left, always visible). |
| Adjust mode | Crosshair pin at centre, hint text, Confirm / Cancel. |
| Web unblock guide | Short dialog: `web_unblock_title`, `web_unblock_guide`, "OK". |

**States on S2:** loading (spinner chip), loaded, empty (US-1.2 AC4), error/offline (banner + Retry), location needed / off / blocked / no fix / outside area / low accuracy (banners, max 1 shown — priority: offline/error > permission/GPS/no fix > outside area > low accuracy). A dismissed banner (outside area, low accuracy) is skipped for the rest of the session and the next banner in priority is shown.

**Android vs Web**
| Topic | Android | Web (Chrome / iPhone Safari) |
|---|---|---|
| Permission prompt | OS dialog (`geolocator`), "while in use" only | Browser prompt; HTTPS required |
| Denied forever | Open app settings | Cannot reopen prompt → `PERMISSION_DENIED` from Geolocation API → unblock guide (no reliance on Permissions API) |
| GPS off | Detectable → "Location is off" + open location settings | Not detectable → treated as timeout (US-1.1 AC9) |
| Last-known position | `getLastKnownPosition`, used if < 5 min old | Not available → default centre on timeout |
| Approximate location | Android 12+ option → low accuracy (US-1.3) | Desktop is often Wi-Fi/IP based → low accuracy is common |
| Connectivity (auto retry) | connectivity change event | `online` event only |
| Background location | Never requested | n/a |

## 4. Business rules
- **BR-1 Search radius:** default 1000 m; "Expand" = 3000 m; server clamps to [100, 5000] m. *(assumption — PO to confirm)* Every new search (BR-3 (a)–(d)) starts at the default/area radius; Expand applies only to the current search (**D5**).
- **BR-2 Max pins:** the RPC returns at most 50 lots, nearest first. *(assumption — PO to confirm)*
- **BR-3 Refresh:** lots are loaded only on these triggers:
  (a) first position — first GPS fix, last-known position, default centre (no permission / timeout), or a late first fix (US-1.1 AC12);
  (b) "My location"; (c) confirming a manual position; (d) "Search this area";
  (e) Retry, Expand, or the single automatic retry on reconnect (US-1.2 AC5) — these repeat or extend the **current** search.
  "Search this area" appears when the map centre moved, in screen pixels, > 30% of the viewport **width** horizontally **or** > 30% of the viewport **height** vertically from the last search centre, or the zoom changed by ≥ 1 level (Q-QA-12, *Tech Lead decision — PO approves via PR*). The area-search radius is half the visible diagonal, clamped to [300, 5000] m. Pan/zoom never triggers an automatic query (saves free-tier quota and battery).
- **BR-4 Clustering:** markers closer than 60 px are clustered below zoom 17. At zoom ≥ 17 only markers that still overlap (< 20 px apart) stay clustered; tapping such a cluster at max zoom (18) spiderfies it. *(Tech Lead decision — PO approves via PR)*
- **BR-5 Default centre:** Bãi Trước (Front Beach), approx. **10.3460, 107.0740**, zoom 15. *(assumption — PO to confirm)*
- **BR-6 Pin style:** motorbike-only = motorbike icon, green; car-only = car icon, blue; both = combined icon, purple. The selected pin is enlarged. Red/amber are reserved for availability (US-6.7). *(colours: assumption — design to confirm)*
- **BR-7 Low accuracy:** accuracy > 100 m (100 m itself is not low), or approximate-only permission.
- **BR-8 Position source priority:** manual (if set) > GPS fix > last known (< 5 min, Android only) > default centre.
- **BR-9 Consent (US-1.4):** location APIs are called only after in-app consent. The consent result (result + version + timestamp) is stored **on the device only**. Declining never blocks the app.
- **BR-10 No server-side location (PDPL):** user/manual coordinates are sent only as `nearby_lots` parameters via HTTP **POST** body (never in the URL/query string), rounded to 4 decimals (~11 m) *(assumption — PO to confirm)*, never written to any table, and never sent to analytics/Crashlytics.
- **BR-11 Distance on card:** computed client-side (haversine) from the current position (BR-8), not from the search centre. **v0.3 (D7):** only a real user position counts — manual (US-1.3), GPS fix or last-known. With no user position (consent declined, permission denied/blocked, GPS off, timeout without last-known) the distance is **hidden**; the default centre is never used as a distance source.
- **BR-12 Service area:** Vũng Tàu bounding box lat 10.30–10.45, lng 107.03–107.20 *(assumption — PO to confirm)*. Edges are **inclusive** (a point exactly on an edge is inside) (Q-QA-6, *Tech Lead decision — PO approves via PR*).
- **BR-13 Tile attribution (v0.4, D5):** the attribution must always be visible (bottom-left; never covered by card, banner or FAB) and is not translated. With OpenFreeMap (ADR-0009) the exact text is **"OpenFreeMap © OpenMapTiles Data from OpenStreetMap"** (source: openfreemap.org "Attribution", ADR-0009 spike §3). The text comes from the tile config (`TILE_ATTRIBUTION`, default = that text), never hard-coded in widgets; another provider brings its own required text in its config (e.g. "© OpenStreetMap contributors" for tile.openstreetmap.org in local dev).
- **BR-14 Search point (D4):** for position-based triggers (BR-3 (a)–(c)) the search point is the current position (BR-8) if it is inside the service area, otherwise the default centre (BR-5). For "Search this area" it is the map centre (inside or outside the area).
- **BR-15 Distance format (D3):** round the distance to the nearest 10 m first; if the rounded value is < 1000 m show metres (`"{m} m"`, e.g. "350 m", minimum "10 m"); otherwise km with one decimal (`"{km} km"`, e.g. "1.2 km"; 995 m → "1.0 km"). The decimal separator follows the locale: vi "1,2 km", en "1.2 km". *(locale separator: Tech Lead decision — PO approves via PR)*
- **BR-16 Customer-only lots (v0.4, D2):** lots that OSM tags `access=customers` (parking for customers of a shop, hotel, restaurant …) are **kept and shown** like other lots (same pin style, BR-6), and their mini card shows the label `label_customers_only` ("Customers only") under the name. Stored as `parking_lots.customers_only boolean not null default false`; the OSM import (US-4.1) sets it to true for `access=customers` and false otherwise (`access=private`/`no` lots stay excluded). Owners/admins can change it later (SPEC-004). *(Tech Lead decision — PO approves via PR: label on the card only, no separate pin style)*
- **BR-17 Map label language (v0.4):** place and street names drawn by the map style follow the app locale (§6): **vi** → the local name (OSM `name`); **en** → the English name (`name:en`) where OSM has one, otherwise the local name. Applied on the client when the vector style is loaded (no extra tiles, no extra requests); a locale change applies on the next map/style load. Raster tiles (local dev only) cannot be changed and are exempt. *(Tech Lead decision — PO approves via PR; from the ADR-0009 spike finding §8.3)*

## 5. Data & API
**Table used (read-only):** `parking_lots` (id, name, location `geography(Point,4326)`, address, vehicle_types `text[]` ∈ {`motorbike`,`car`}, is_verified, customers_only). No writes. No new tables. **v0.4:** new column `customers_only boolean not null default false` (BR-16) via a new migration; the RPC returns it (below); the US-4.1 import script sets it.
E1 shows every row of `parking_lots`; there is no active/closed flag. If one is needed it is specified in SPEC-004 and the RPC gets a non-breaking filter then (spec §9 item 5). *(Tech Lead decision — PO approves via PR)*

**Index**
```sql
create index if not exists parking_lots_location_gix on public.parking_lots using gist (location);
```

**RPC** (`supabase.rpc('nearby_lots', params: {...})` → `POST /rest/v1/rpc/nearby_lots`)
```sql
create or replace function public.nearby_lots(
  lat double precision,
  lng double precision,
  radius_m integer default 1000,
  vehicle_type text default null          -- 'motorbike' | 'car' | null = all (filter UI is E2)
) returns table (
  id uuid, name text, address text,
  lot_lat double precision, lot_lng double precision,   -- not "lat/lng": output names must differ from input params
  vehicle_types text[], is_verified boolean, customers_only boolean,   -- customers_only: v0.4, BR-16
  distance_m integer
)
language sql stable security invoker
set search_path = public, extensions
as $$
  with p as (select st_setsrid(st_makepoint(lng, lat), 4326)::geography as g)  -- note: lng first
  select l.id, l.name, l.address,
         st_y(l.location::geometry), st_x(l.location::geometry),
         l.vehicle_types, l.is_verified, l.customers_only,
         round(st_distance(l.location, p.g))::int as distance_m
  from public.parking_lots l, p
  where st_dwithin(l.location, p.g, least(greatest(radius_m, 100), 5000))
    and (vehicle_type is null or vehicle_type = any(l.vehicle_types))
  order by distance_m asc, l.id asc
  limit 50;
$$;
grant execute on function public.nearby_lots(double precision, double precision, integer, text) to anon, authenticated;
```
- Invalid input (lat ∉ [-90, 90], lng ∉ [-180, 180], unknown vehicle_type) → empty result or error; the client never sends those.
- Ordering: distance ascending, tie-break by id. Limit: 50 (BR-2). `distance_m` is from the search point; the card uses BR-11 instead.

**RLS**
```sql
alter table public.parking_lots enable row level security;
create policy "lots_public_read" on public.parking_lots for select to anon, authenticated using (true);
```
(Write policies: SPEC-004 / SPEC-006.)

**Example request**
```json
POST /rest/v1/rpc/nearby_lots
{ "lat": 10.3460, "lng": 107.0740, "radius_m": 1000, "vehicle_type": null }
```
**Example response**
```json
[
  { "id": "5b1c…", "name": "Bãi giữ xe Quang Trung", "address": "Quang Trung, Vũng Tàu",
    "lot_lat": 10.3466, "lot_lng": 107.0752, "vehicle_types": ["motorbike","car"],
    "is_verified": false, "customers_only": false, "distance_m": 145 },
  { "id": "9e7a…", "name": "Bãi xe Bạch Dinh", "address": "Trần Phú, Vũng Tàu",
    "lot_lat": 10.3512, "lot_lng": 107.0701, "vehicle_types": ["car"],
    "is_verified": false, "customers_only": false, "distance_m": 720 }
]
```

## 6. Non-functional
| ID | Requirement |
|---|---|
| NFR-1 | Pins visible ≤ 2 s (p75) after the position is known, on 4G, mid-range Android; ≤ 3 s on low-end device. Measured with a client timer (position known → pins rendered) logged in debug/profile builds without coordinates (same value as `duration_ms`), ≥ 20 runs per device; stopwatch runs are indicative only (Q-QA-9). *(Tech Lead decision — PO approves via PR)* |
| NFR-2 | Map first tiles ≤ 3 s cold start on 4G; response ≤ 20 KB at 50 lots. RPC server time ≤ 300 ms p95 for ≤ 5,000 lots is a **DB performance check** (supabase-dev): `explain analyze` on a generated 5,000-lot local dataset, run once per sprint, informational — not a CI gate (Q-QA-9). *(Tech Lead decision — PO approves via PR)* |
| NFR-3a | Tile caching: on-device HTTP cache (MIT-licensed package — Tech Lead to confirm; avoid GPL packages), TTL ≥ 7 days, no bulk prefetch (provider ToS). TTL is verified by config review / unit test of the cache settings (Q-QA-21). |
| NFR-3b | Monthly tile quota monitoring with an alert at 80% is an **ops** requirement owned by ADR-0009: **n/a for OpenFreeMap (no quota)**; required only if fallback 4a (Stadia/MapTiler) is used. Not an app AC and not tested in a sprint (Q-QA-21). |
| NFR-4 | Offline: cached tiles + blue dot still work; lots show the error banner (US-1.2 AC5); last pins kept for the session only |
| NFR-5 | Battery: foreground location only, distance filter 10 m, stream stopped when the app is backgrounded |
| NFR-6 | Privacy/PDPL: BR-9, BR-10; logs must not contain coordinates (POST body only); Crashlytics breadcrumbs must not contain coordinates. Firebase Analytics/Crashlytics (free, ADR-0002) ship with **collection disabled by default** until the analytics-consent question (§9 item 4) is answered in SPEC-005; events in this section are implemented behind that switch and tested on a debug build with collection force-enabled (DebugView). Crashlytics has no Web SDK — Web is checked on Console/network only (Q-QA-20). *(Tech Lead decision — PO approves via PR)* |
| NFR-7 | Security: anon key only; `security invoker` RPC; RLS on |
| NFR-8 | Accessibility: pins/buttons have semantics labels (keys `a11y_*` below); touch targets ≥ 48 dp |

**Localisation (vi/en; framework per SPEC-005)** — **vi wording: PO to review (D2, MTG-2026-11-24-po-decisions A2).** `{…}` are placeholders.
| Key | vi | en | Used in |
|---|---|---|---|
| consent_title | Cho phép truy cập vị trí | Allow location access | US-1.4 AC2 |
| consent_body | ParkFinder chỉ dùng vị trí của bạn khi bạn đang mở ứng dụng, để hiển thị các bãi xe gần bạn. Vị trí không được lưu trên máy chủ của chúng tôi. Bạn có thể tắt quyền này bất cứ lúc nào trong cài đặt của thiết bị hoặc trình duyệt. | ParkFinder uses your location only while the app is open, to show parking lots near you. Your location is not stored on our servers. You can turn this off at any time in your device or browser settings. | US-1.4 AC2 |
| consent_privacy_link | Chính sách quyền riêng tư | Privacy policy | US-1.4 AC2 (after US-5.2) |
| btn_allow | Cho phép | Allow | US-1.4 |
| btn_not_now | Để sau | Not now | US-1.4 |
| banner_location_needed | Bật định vị để xem bãi xe gần bạn | Turn on location to see lots near you | US-1.1 AC3/AC4 |
| btn_enable | Bật | Enable | US-1.1 AC3–AC5 |
| web_unblock_title | Vị trí đang bị chặn | Location is blocked | US-1.1 AC5 |
| web_unblock_guide | Trang này đang bị chặn truy cập vị trí. Hãy mở cài đặt trang web của trình duyệt, cho phép Vị trí, rồi tải lại trang. | Location is blocked for this site. Open your browser's site settings, allow Location, then reload the page. | US-1.1 AC5 |
| btn_ok | OK | OK | Web unblock guide |
| banner_location_off | Định vị đang tắt | Location is off | US-1.1 AC6 |
| btn_turn_on | Bật định vị | Turn on | US-1.1 AC6 |
| hint_locating | Đang định vị… | Locating… | US-1.1 AC9 |
| banner_no_fix | Không lấy được vị trí của bạn — chỉnh thủ công? | Can't get your location — adjust manually? | US-1.1 AC9 |
| out_of_area | Hiện ParkFinder chỉ hỗ trợ Vũng Tàu | ParkFinder currently covers Vũng Tàu only | US-1.1 AC10 |
| btn_go_vung_tau | Đến Vũng Tàu | Go to Vũng Tàu | US-1.1 AC10 |
| btn_search_area | Tìm trong khu vực này | Search this area | US-1.2 AC6 |
| empty_radius | Không có bãi xe trong bán kính {km} km | No parking lots within {km} km | US-1.2 AC4 |
| btn_expand | Mở rộng đến {km} km | Expand to {km} km | US-1.2 AC4 |
| empty_none | Chưa tìm thấy bãi xe nào gần đây | No parking lots found nearby yet | US-1.2 AC4 |
| empty_area | Không có bãi xe trong khu vực này | No parking lots in this area | US-1.2 AC4 |
| error_load | Không tải được bãi xe | Can't load parking lots | US-1.2 AC5 |
| btn_retry | Thử lại | Retry | US-1.2 AC5 |
| hint_cap | Đang hiển thị {n} bãi gần nhất — phóng to để xem thêm | Showing nearest {n} — zoom in to see more | US-1.2 AC9 ({n} = 50) |
| distance_m / distance_km | {m} m / {km} km | {m} m / {km} km | US-1.2 AC8, BR-15 |
| vehicle_motorbike / vehicle_car | Xe máy / Ô tô | Motorbike / Car | US-1.2 AC8 card |
| label_customers_only | Chỉ dành cho khách | Customers only | US-1.2 AC8 card, BR-16 (v0.4) |
| banner_low_accuracy | Vị trí có thể chưa chính xác | Your location may be inaccurate | US-1.3 AC1 |
| btn_adjust / btn_confirm / btn_cancel | Chỉnh vị trí / Xác nhận / Hủy | Adjust / Confirm / Cancel | US-1.3 |
| menu_set_position | Đặt vị trí của tôi | Set my position | US-1.3 AC2 |
| hint_adjust | Di chuyển bản đồ đến đúng vị trí của bạn | Move the map to your exact position | US-1.3 AC2 |
| toast_using_gps | Đang dùng vị trí GPS | Using GPS location | US-1.3 AC4 |
| a11y_dismiss | Đóng | Dismiss | banner × (US-1.1 AC10, US-1.3 AC1) |
| a11y_my_location | Vị trí của tôi | My location | FAB |
| a11y_pin | {name}, {types} | {name}, {types} | pin semantics |
| a11y_cluster | {count} bãi xe | {count} parking lots | cluster semantics |
| a11y_manual_marker | Vị trí của bạn (đặt thủ công) | Your position (set manually) | US-1.3 AC3 |

Not translated: the tile attribution (BR-13). Map labels drawn by the style follow BR-17.

**Analytics events (Firebase; collection off by default per NFR-6; never include coordinates or addresses)**
`location_consent_shown`, `location_consent_result {result}`, `location_permission_result {status}`, `location_fix {accuracy_bucket, ttf_bucket}`, `nearby_lots_loaded {count, radius_m, trigger, duration_ms}`, `nearby_lots_empty {radius_m, trigger}`, `nearby_lots_error {error_type}`, `search_area_tapped`, `recenter_tapped`, `manual_position_set {trigger}`, `cluster_tapped`, `lot_pin_tapped {lot_id}`, `lot_card_opened {lot_id}`, `out_of_area_shown`, `banner_dismissed {banner}`.

## 7. Out of scope
- Vehicle type / open-now / price filters and the list view (E2, SPEC-002). The RPC already accepts `vehicle_type`.
- Lot detail screen and "Navigate" (E3, SPEC-003). E1 ends at the mini card → `/lot/:id`.
- Verified badge and live availability on pins (US-6.7, SPEC-006).
- Full privacy policy content, in-app consent withdrawal setting and the i18n framework (US-5.2, SPEC-005). E1 uses them. (The minimal consent screen S1 is in scope: US-1.4.)
- Address/place search, routing, background location, storing location history, persisting the manual position, iOS native app.

## 8. Test notes
**Mock GPS points** (approximate — QA verifies each point against the seeded data with supabase-dev before first execution; this is an entry criterion for running E1 tests, Q-QA-23)
| ID | Place | Lat, Lng | Purpose |
|---|---|---|---|
| MP-1 | Bãi Trước (Front Beach) | 10.3460, 107.0740 | Default centre, dense, tourists |
| MP-2 | Bãi Sau (Back Beach, Thùy Vân) | 10.3440, 107.0960 | Dense pins, clustering |
| MP-3 | Tượng Chúa Kitô | 10.3265, 107.0845 | Hilly, low accuracy (set accuracy 150 m) |
| MP-4 | City centre / Chợ Vũng Tàu | 10.3500, 107.0820 | Narrow streets |
| MP-5 | Offshore east of Bãi Sau | 10.3400, 107.1150 | Empty state at 1 km |
| MP-6 | HCMC District 1 | 10.7769, 106.7009 | Outside service area |
| MP-7 | North-west corner of service area | 10.4400, 107.0400 | Inside area, 0 lots within 3 km (TC-1.2.12) *(coordinates: Tech Lead proposal, QA to verify)* |

**Test data:** seed ≥ 60 lots around MP-2 (cap/cluster tests), a mix of vehicle types, 0 lots within 1 km of MP-5, ≥ 1 lot within 3 km of MP-5, **0 lots within 3 km of MP-7**, ≥ 2 lots with identical coordinates (spiderfy, US-1.2 AC7). Owner: supabase-dev, as a **local-only** seed file under `supabase/` (never pushed to cloud) (Q-QA-3, MTG-2026-11-24-po-decisions A5). A 5,000-lot generated dataset for NFR-2 is a separate local script.

**Verification limits (Q-QA-19):** "memory only" (US-1.3 AC7) and "device only" (US-1.4 AC7) are verified by storage inspection on a **debug** build (TC-1.3.12, TC-1.4.5); release builds are covered by TC-1.3.6 and code review.

**TC ID changes in v0.2:** TC-1.1.1 moved to US-1.4 as **TC-1.4.1** (ID TC-1.1.1 is retired, not reused). In `docs/06-qa/test-cases/E1.md` (QA-owned, A3), TC-1.1.17 and TC-1.1.18 map to TC-1.4.4 and TC-1.4.5. New ACs (US-1.1 AC12, US-1.2 AC11, US-1.3 AC8, dismiss actions, BR-15, BR-14) need test cases from QA.

| TC | Story/AC | Case |
|---|---|---|
| TC-1.1.1 | — | **Moved → TC-1.4.1** (US-1.4 AC1) |
| TC-1.1.2 | AC2 | Grant at MP-1 → centred, blue dot + accuracy circle, follow mode on |
| TC-1.1.3 | AC3 | "Not now" → default centre, banner, no OS prompt |
| TC-1.1.4 | AC4 | Deny once → banner; Enable re-prompts |
| TC-1.1.5 | AC5 | Android "Don't ask again" → opens app settings; Web blocked → unblock guide |
| TC-1.1.6 | AC6 | Android GPS off → banner; turn on → fix ≤ 5 s from resume |
| TC-1.1.7 | AC7/AC8 | Mock route MP-1→MP-4; dot moves; pan, then My location recenters |
| TC-1.1.8 | AC9 | No fix (indoor / mock disabled) → timeout handling after 10 s |
| TC-1.1.9 | AC10 | MP-6 → blue dot at MP-6, lots around default centre, out-of-area banner, "Go to Vũng Tàu" |
| TC-1.1.10 | AC11 | Web Chrome + iPhone Safari over HTTPS; HTTP/unsupported → no error |
| TC-1.2.1 | 1.2 AC1/NFR-1 | MP-1 on 4G (and throttled) → pins ≤ 2 s |
| TC-1.2.2 | AC2 | Correct icon for motorbike / car / both |
| TC-1.2.3 | AC4 | MP-5 → empty state; Expand → 3 km results; next trigger back to 1 km |
| TC-1.2.4 | AC5 | Airplane mode → error banner, pins kept; reconnect → one auto retry |
| TC-1.2.5 | AC6 | Pan > 30% → button appears; no request on pan (network log); tap → reload |
| TC-1.2.6 | AC7/AC9 | MP-2 → clusters, cap hint at 50; zoom 17 → no clusters except overlapping markers |
| TC-1.2.7 | AC8 | Tap pin → card with client-side distance in BR-15 format; tap card → `/lot/:id` |
| TC-1.2.8 | DB | RPC: ordering, limit 50, radius clamp, `vehicle_type` filter, anon can execute, RLS on (SQL test) |
| TC-1.2.9 | PDPL | Inspect traffic: coordinates only in POST body, rounded to 4 decimals; no coordinates in analytics/Crashlytics; no table writes |
| TC-1.3.1 | 1.3 AC1 | MP-3 with 150 m accuracy / Android approximate → low-accuracy banner; close → not shown again this session |
| TC-1.3.2 | AC2/AC3 | Adjust → move → Confirm → manual marker, lots reloaded at 1 km |
| TC-1.3.3 | AC4 | Mock GPS moves while manual → no change; My location → back to GPS |
| TC-1.3.4 | AC5 | Cancel → unchanged |
| TC-1.3.5 | AC6 | Permission denied → manual position works |
| TC-1.3.6 | AC7 | Restart / reload → manual position cleared |
| TC-1.3.7 | AC2 | Long-press → adjust mode with the pressed point under the crosshair |
| TC-1.4.1 | 1.4 AC1 | Fresh install → S1 shown before OS prompt; no location call incl. last-known (check logs) *(was TC-1.1.1)* |
| TC-1.4.2 | AC2/AC3 | S1 shows title, notice text, Allow / Not now; Allow → OS/browser prompt appears only now |
| TC-1.4.3 | AC4/AC5 | Not now → no prompt, map usable; relaunch → S1 not shown; "Enable" → S1 reopens |
| TC-1.4.4 | AC6 | Build with bumped consent version → S1 shown again before any location call |
| TC-1.4.5 | AC7 | Consent result only in SharedPreferences / localStorage; no network request carries it; clear data → S1 again |
| TC-1.4.6 | AC8 | Revoke OS/browser permission after granting → behaves as US-1.1 AC4/AC5, no crash |
| TC-1.4.7 | AC2, §6 | vi and en: S1 strings match §6 keys; no truncation on low-end screen |

Devices: per the test-strategy matrix (low-end Android, mid Android, iPhone Safari, desktop Chrome).

## 9. Open questions (PO to decide)
1. Confirm defaults: radius 1/3/5 km, 50-pin cap, default centre Bãi Trước, service-area box, rounding to 4 decimals. *(still open — assumptions)*
2. ~~Pull minimal consent S1 into Sprint 1?~~ **Resolved — D1** (US-1.4).
3. ~~Tile provider~~ **Resolved 2026-11-24 by ADR-0009** (OpenFreeMap vector tiles, conditional on the Sprint 1 spike; MTG-2026-11-24-po-decisions D8/D9).
4. Does Firebase Analytics need its own consent under PDPL (SPEC-005)? **Still open (legal/PO).** Interim Tech Lead default: collection disabled (NFR-6).
5. ~~Hide inactive/closed lots?~~ **Resolved (Tech Lead decision):** E1 shows all rows; any active flag is specified in SPEC-004 (§5).
6. ~~Manual position persistence?~~ **Resolved (Tech Lead decision):** session only (US-1.3 AC7).
7. Figma mockups owner and date (DoR blocker). **Still open.**
- **Q-B (new):** For Sprint 1, is the S1 minimal notice (`consent_body`) without a full privacy-policy link sufficient for the closed beta under PDPL, or must a short privacy page ship with US-1.4? (scope/legal — PO)
- **Q-C (new):** Should an in-app "withdraw location consent" setting be added to E1 or stay in US-5.2? Today withdrawal is via OS/browser settings only (US-1.4 AC8). (scope — PO)
- **Q-D (new):** Confirm the vi strings in §6 and the vi decimal comma in BR-15 ("1,2 km"). (D2 / A2)
- **Q-E (v0.4):** Confirm the customer-only label wording (`label_customers_only`: vi "Chỉ dành cho khách", en "Customers only") and that it is shown on the card only, not as a separate pin style (BR-16). (D2 / A2)

**Resolved questions (QA → resolution)**
| Q-QA | Resolution | Where |
|---|---|---|
| Q-QA-1 | D1: S1 is US-1.4 in Sprint 1 | US-1.4, header |
| Q-QA-2 | D2: all strings keyed, vi drafted | §6 Localisation |
| Q-QA-3 | MP-7 + local-only seed owned by supabase-dev | §8 Test data |
| Q-QA-4 | 5 s measured from return to foreground | US-1.1 AC6 |
| Q-QA-5 | Web GPS-off = timeout (AC9); no Web "Turn on" | US-1.1 AC6, §3 |
| Q-QA-6 | Edges inclusive; D4: lots around default centre | BR-12, BR-14, US-1.1 AC10 |
| Q-QA-7 | Follow mode on after first fix | US-1.1 AC2, AC7 |
| Q-QA-8 | Late fix handling; last-known Android only | US-1.1 AC9, AC12 |
| Q-QA-9 | Client timer ≥ 20 runs; DB perf check not a CI gate | NFR-1, NFR-2 |
| Q-QA-10 | D5: new trigger resets to 1 km; area search empty → `empty_area`, no Expand | US-1.2 AC4, BR-1 |
| Q-QA-11 | One auto retry on offline→online only (Web `online` event); never on HTTP errors | US-1.2 AC5 |
| Q-QA-12 | 30% width horizontally or 30% height vertically | BR-3 |
| Q-QA-13 | Overlapping markers stay clustered; spiderfy at max zoom 18 | US-1.2 AC7, BR-4 |
| Q-QA-14 | Hint shown at exactly 50; accepted | US-1.2 AC9 |
| Q-QA-15 | D3 distance format | BR-15, US-1.2 AC8 |
| Q-QA-16 | D6 dismissible, not again this session | US-1.3 AC1 |
| Q-QA-17 | AC9 banner opens adjust mode; long-press in adjust mode moves point under crosshair | US-1.3 AC2 |
| Q-QA-18 | Manual outside area = D4; "My location" without permission/GPS keeps manual and runs Enable/Turn on | US-1.3 AC4, AC8 |
| Q-QA-19 | Debug-build storage inspection + TC-1.3.6 + code review | §8 Verification limits |
| Q-QA-20 | Firebase is in ADR-0002; collection off by default; test on debug build with DebugView | NFR-6 |
| Q-QA-21 | TTL via config review/unit test; quota alert moved to tile ADR (ops) | NFR-3a, NFR-3b |
| Q-QA-22 | Web: Geolocation API `PERMISSION_DENIED` → guide; no reliance on Permissions API | US-1.1 AC5, §3 |
| Q-QA-23 | Mock-point verification is an entry criterion for test execution | §8 |

## 10. Change history
| Version | Date | Change | By |
|---|---|---|---|
| 0.1 | 2026-11-24 | Initial draft (drafted by Plan sub-agent, reviewed by Claude main agent) | Tech Lead |
| 0.2 | 2026-11-24 | Applied PO decisions D1–D6 (MTG-2026-11-24-po-decisions): new US-1.4 consent (D1, US-1.1 AC1 and TC-1.1.1 moved), full vi/en string table (D2), distance format BR-15 (D3), outside-area search point BR-14 (D4), radius reset per search (D5), dismissible low-accuracy banner (D6). All Q-QA-1–23 resolved: by PO decision Q-QA-1 (D1), 2 (D2), 15 (D3), 16 (D6), 6 and 10 in part (D4, D5); by Tech Lead decision (PO approves via PR) the rest; §9 items 5 and 6 resolved; new ACs US-1.1 AC12, US-1.2 AC11, US-1.3 AC8; NFR-3 split into 3a/3b; MP-7 added; open questions Q-B–Q-D added. Tile provider, analytics consent, defaults and Figma remain open. | Tech Lead |
| 0.3 | 2026-11-25 | PO decision **D7** (review of PR #27): BR-11 / US-1.2 AC8 — card distance hidden when there is no user position (no longer measured from the default centre). TC-1.2.7 / 1.2.17 / 1.2.24 unchanged; QA to add a no-location card case. | PO / main agent (Tech Lead to review in PR #27) |
| 0.3.1 | 2026-11-26 | US-1.1 AC5: blocked state remembered on the device, first "Enable" after relaunch opens settings (#32). US-1.1 AC6: declined Google "Location Accuracy" dialog is handled as AC9, not "location off" (#31). Found by the Android emulator QA run. | Tech Lead (main agent) |
| 0.4 | 2026-11-28 | Task #17 (MTG-2026-11-24-po-decisions-2 A2): BR-13 exact OpenFreeMap attribution (D5); new BR-16 customer-only lots kept with a card label (D2) — new column `parking_lots.customers_only`, RPC output field, US-1.2 AC8 card label, key `label_customers_only`; new BR-17 map label language follows the app locale (spike §8.3). Implementation needs a new migration, an import-script change and app work (follow-up task). | Tech Lead (main agent) |
