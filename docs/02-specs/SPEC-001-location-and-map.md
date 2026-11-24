# SPEC-001: Location & Map

| Field | Value |
|---|---|
| Epic | E1 |
| Status | Draft |
| Version | 0.1 |
| Author | Tech Lead (with PO) |
| Reviewers | PO, Tech Lead, QA |
| Last updated | 2026-11-24 |
| Related | ADR-0002, MTG-2026-11-24-kickoff, US-1.1, US-1.2, US-1.3 · depends on US-4.1 (lot data), US-5.2 (consent) |

## 1. Goal
Deliver the core of the vision: *"Open the app, see the nearest suitable parking lot."* A driver (tourist by car or local on a motorbike) opens ParkFinder in Vũng Tàu and immediately sees **where they are** and **which parking lots are around them**, even when GPS is weak or location is not shared.
E1 is the entry screen of Driver mode. It hands off to E2 (filters/list), E3 (lot details) and E6 (verified badge/availability).
Sprint goal link: Sprint 1 — *"A user can open the app and see their location + nearby lots on the map."*

## 2. User stories & acceptance criteria

### US-1.1 — See my current position on a map
**As a** driver, **I want** to see my current position on a map, **so that** I can orient myself and find parking around me.

- **AC1 (consent first):** Given a first launch, when the app opens, then the in-app location consent screen (S1) is shown **before** any OS/browser permission prompt, and no location API is called before the user taps "Allow".
- **AC2 (granted):** Given the user accepts consent and grants permission, when a position fix arrives, then the map centres on the user at zoom 16 with a blue dot and an accuracy circle (radius = reported accuracy).
- **AC3 (declined in-app):** Given the user taps "Not now" on S1, when the map opens, then no OS prompt appears, the map is centred on the default centre (BR-5), and a banner shows "Turn on location to see lots near you" with an "Enable" action that reopens S1.
- **AC4 (denied once):** Given the OS/browser prompt is denied, when the map opens, then behaviour equals AC3 and "Enable" re-requests the permission.
- **AC5 (denied forever / blocked):** Given Android "Don't ask again" or Web site permission "Blocked", when the user taps "Enable", then Android opens the app settings page; Web shows a short guide to unblock location in browser settings (no prompt is possible).
- **AC6 (GPS off):** Given permission is granted but device location services are off, when the map opens, then a banner "Location is off" with "Turn on" is shown (Android opens location settings; Web shows a hint); when the user returns with location on, the app gets a fix within 5 s without restart.
- **AC7 (movement):** Given the map is showing the user, when the user moves ≥ 10 m, then the blue dot moves. The camera follows only if follow mode is on (follow mode is on after the "My location" button is tapped and switches off when the user pans).
- **AC8 (recenter):** Given the user has panned away, when they tap the "My location" button, then the map animates back to the current position at zoom 16 and lots are reloaded (BR-3).
- **AC9 (timeout):** Given no fix within 10 s, when a last-known position < 5 min old exists, then it is shown with a "Locating…" hint; otherwise the default centre is used and the banner "Can't get your location — adjust manually?" (links to US-1.3) is shown.
- **AC10 (outside pilot area):** Given the user's position is outside the service area (BR-12), when the fix arrives, then the blue dot is shown, plus a banner "ParkFinder currently covers Vũng Tàu only" with "Go to Vũng Tàu" (moves the map to the default centre).
- **AC11 (Web):** Given the Web build on HTTPS, when the user grants browser geolocation, then AC2–AC10 behave the same. If the Geolocation API is unavailable (non-HTTPS or unsupported), the app behaves as in AC3 without errors.

### US-1.2 — See nearby parking lots as pins
**As a** driver, **I want** to see nearby parking lots as pins on the map, **so that** I can quickly pick the closest suitable one.

- **AC1 (initial load):** Given a position (GPS, manual or default centre), when the map opens, then `nearby_lots` is called with that point and `radius_m = 1000`, and pins appear within 2 s on 4G (NFR-1).
- **AC2 (pin style):** Given lots are returned, then each pin shows the icon for its vehicle types: motorbike, car, or both (BR-6).
- **AC3 (loading):** Given a request is in flight, then a non-blocking progress indicator is visible, the map stays pannable/zoomable, and the previous pins stay visible.
- **AC4 (empty):** Given 0 lots in radius, then the message "No parking lots within 1 km" is shown with an "Expand to 3 km" action; after expanding, the radius is 3000 m. If still 0, the message is "No parking lots found nearby yet".
- **AC5 (error/offline):** Given the request fails or there is no internet, then the banner "Can't load parking lots" + "Retry" is shown, existing pins are kept, and no crash or blank screen occurs. When connectivity returns, the app retries once automatically.
- **AC6 (search this area):** Given the user pans or zooms beyond BR-3's threshold, then a "Search this area" button appears; when tapped, lots are loaded around the map centre (radius per BR-3) and the button hides. Lots are **never** reloaded automatically on pan/zoom.
- **AC7 (clustering):** Given ≥ 2 pins overlap on screen (BR-4), then they are shown as one cluster with a count; tapping the cluster zooms in until the pins separate.
- **AC8 (tap pin → hand-off):** Given pins are shown, when the user taps a pin, then it is highlighted and a mini card shows name, vehicle types and distance from the user's position; tapping the card opens the lot detail screen (SPEC-003, US-3.1). Out of scope here beyond navigation to route `/lot/:id`.
- **AC9 (cap):** Given the RPC returns the maximum of 50 lots, then a hint "Showing nearest 50 — zoom in to see more" is shown.
- **AC10 (no location):** Given location is unavailable (US-1.1 AC3/AC4/AC5), then lots are still loaded around the default centre.

### US-1.3 — Adjust my position manually
**As a** driver, **I want** to adjust my position manually when GPS is inaccurate, **so that** the nearby lots and distances are correct for where I really am.

- **AC1 (low-accuracy prompt):** Given a fix with accuracy > 100 m (or Android "approximate" permission only), then the banner "Your location may be inaccurate" with "Adjust" is shown.
- **AC2 (enter adjust mode):** Given the map screen, when the user taps "Adjust" (banner, or the overflow menu item "Set my position") or long-presses the map, then adjust mode starts: a fixed crosshair pin at the screen centre (at the long-press point when long-pressed), the hint "Move the map to your exact position", and "Confirm" / "Cancel" buttons.
- **AC3 (confirm):** When the user taps "Confirm", then the manual position replaces the blue dot with the "manual" marker style, lots are reloaded around it (radius 1000 m), and card distances are computed from it.
- **AC4 (GPS ignored while manual):** Given a manual position is active, when new GPS fixes arrive, then the position does not change. Tapping "My location" switches back to GPS (confirmation toast "Using GPS location").
- **AC5 (cancel):** When the user taps "Cancel", then the previous position and pins are unchanged.
- **AC6 (no GPS needed):** Given location permission is denied or GPS is off, then the user can still set a manual position and get nearby lots.
- **AC7 (privacy):** Given a manual position, then it is kept in memory only (cleared on app restart / page reload) and is sent to the server only as RPC parameters (BR-10).

## 3. UX / UI
Figma: _TBD — required before stories are Ready (DoR)._

| Screen / element | Description |
|---|---|
| S1 Consent screen | Explains why location is used, link to the privacy policy (SPEC-005), buttons "Allow" / "Not now". Shown on first launch, and again if the consent version changes. |
| S2 Map screen | Full-screen `flutter_map`; blue dot + accuracy circle; "My location" FAB; "Search this area" chip (top centre); banner area (top); lot mini card (bottom); tile attribution (bottom-left, always visible). |
| Adjust mode | Crosshair pin at centre, hint text, Confirm / Cancel. |

**States on S2:** loading (spinner chip), loaded, empty (US-1.2 AC4), error/offline (banner + Retry), location off / denied / blocked / low accuracy / outside area (banners, max 1 shown — priority: offline > permission/GPS > outside area > low accuracy).

**Android vs Web**
| Topic | Android | Web (Chrome / iPhone Safari) |
|---|---|---|
| Permission prompt | OS dialog (`geolocator`), "while in use" only | Browser prompt; HTTPS required |
| Denied forever | Open app settings | Cannot reopen prompt → show instructions |
| GPS off | Detectable → open location settings | Not detectable → treat as timeout (US-1.1 AC9) |
| Approximate location | Android 12+ option → low accuracy (US-1.3) | Desktop is often Wi-Fi/IP based → low accuracy is common |
| Background location | Never requested | n/a |

## 4. Business rules
- **BR-1 Search radius:** default 1000 m; "Expand" = 3000 m; server clamps to [100, 5000] m. *(assumption — PO to confirm)*
- **BR-2 Max pins:** the RPC returns at most 50 lots, nearest first. *(assumption — PO to confirm)*
- **BR-3 Refresh:** lots are reloaded only on (a) the first position fix, (b) "My location", (c) confirming a manual position, (d) "Search this area", (e) Retry/Expand. "Search this area" appears when the map centre moved > 30% of the viewport width from the last search centre, or the zoom changed by ≥ 1 level. The area-search radius is half the visible diagonal, clamped to [300, 5000] m. Pan/zoom never triggers an automatic query (saves free-tier quota and battery).
- **BR-4 Clustering:** markers closer than 60 px are clustered; clustering is disabled at zoom ≥ 17.
- **BR-5 Default centre:** Bãi Trước (Front Beach), approx. **10.3460, 107.0740**, zoom 15. *(assumption — PO to confirm)*
- **BR-6 Pin style:** motorbike-only = motorbike icon, green; car-only = car icon, blue; both = combined icon, purple. The selected pin is enlarged. Red/amber are reserved for availability (US-6.7). *(colours: assumption — design to confirm)*
- **BR-7 Low accuracy:** accuracy > 100 m, or approximate-only permission.
- **BR-8 Position source priority:** manual (if set) > GPS fix > last known (< 5 min) > default centre.
- **BR-9 Consent:** location APIs are called only after in-app consent. The consent result (version + timestamp) is stored **on the device only**. Declining never blocks the app.
- **BR-10 No server-side location (PDPL):** user/manual coordinates are sent only as `nearby_lots` parameters via HTTP **POST** body (never in the URL/query string), rounded to 4 decimals (~11 m) *(assumption — PO to confirm)*, never written to any table, and never sent to analytics/Crashlytics.
- **BR-11 Distance on card:** computed client-side (haversine) from the current position (BR-8), not from the search centre.
- **BR-12 Service area:** Vũng Tàu bounding box lat 10.30–10.45, lng 107.03–107.20. *(assumption — PO to confirm)*
- **BR-13 Tile attribution:** "© OpenStreetMap contributors" + tile provider credit must always be visible.

## 5. Data & API
**Table used (read-only):** `parking_lots` (id, name, location `geography(Point,4326)`, address, vehicle_types `text[]` ∈ {`motorbike`,`car`}, is_verified). No writes. No new tables.

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
  vehicle_types text[], is_verified boolean, distance_m integer
)
language sql stable security invoker
set search_path = public, extensions
as $$
  with p as (select st_setsrid(st_makepoint(lng, lat), 4326)::geography as g)  -- note: lng first
  select l.id, l.name, l.address,
         st_y(l.location::geometry), st_x(l.location::geometry),
         l.vehicle_types, l.is_verified,
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
- Ordering: distance ascending, tie-break by id. Limit: 50 (BR-2).

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
    "is_verified": false, "distance_m": 145 },
  { "id": "9e7a…", "name": "Bãi xe Bạch Dinh", "address": "Trần Phú, Vũng Tàu",
    "lot_lat": 10.3512, "lot_lng": 107.0701, "vehicle_types": ["car"],
    "is_verified": false, "distance_m": 720 }
]
```

## 6. Non-functional
| ID | Requirement |
|---|---|
| NFR-1 | Pins visible ≤ 2 s (p75) after the position is known, on 4G, mid-range Android; ≤ 3 s on low-end device |
| NFR-2 | Map first tiles ≤ 3 s cold start on 4G; RPC server time ≤ 300 ms p95 for ≤ 5,000 lots; response ≤ 20 KB |
| NFR-3 | Tile caching: on-device HTTP cache (MIT-licensed package — Tech Lead to confirm; avoid GPL packages), TTL ≥ 7 days, no bulk prefetch (provider ToS). Monitor monthly tile quota; alert at 80% |
| NFR-4 | Offline: cached tiles + blue dot still work; lots show the error banner (US-1.2 AC5); last pins kept for the session only |
| NFR-5 | Battery: foreground location only, distance filter 10 m, stream stopped when the app is backgrounded |
| NFR-6 | Privacy/PDPL: BR-9, BR-10; logs must not contain coordinates (POST body only); Crashlytics breadcrumbs must not contain coordinates |
| NFR-7 | Security: anon key only; `security invoker` RPC; RLS on |
| NFR-8 | Accessibility: pins/buttons have semantics labels; touch targets ≥ 48 dp |

**Localisation (vi/en; framework per SPEC-005)**
| Key | vi | en |
|---|---|---|
| consent_title | Cho phép truy cập vị trí | Allow location access |
| banner_location_off | Định vị đang tắt | Location is off |
| banner_low_accuracy | Vị trí có thể chưa chính xác | Your location may be inaccurate |
| btn_search_area | Tìm trong khu vực này | Search this area |
| empty_radius | Không có bãi xe trong bán kính {km} km | No parking lots within {km} km |
| error_load | Không tải được bãi xe | Can't load parking lots |
| out_of_area | Hiện ParkFinder chỉ hỗ trợ Vũng Tàu | ParkFinder currently covers Vũng Tàu only |
| btn_adjust / btn_confirm / btn_cancel | Chỉnh vị trí / Xác nhận / Hủy | Adjust / Confirm / Cancel |

**Analytics events (Firebase; never include coordinates or addresses)**
`location_consent_shown`, `location_consent_result {result}`, `location_permission_result {status}`, `location_fix {accuracy_bucket, ttf_bucket}`, `nearby_lots_loaded {count, radius_m, trigger, duration_ms}`, `nearby_lots_empty {radius_m}`, `nearby_lots_error {error_type}`, `search_area_tapped`, `recenter_tapped`, `manual_position_set {trigger}`, `cluster_tapped`, `lot_pin_tapped {lot_id}`, `lot_card_opened {lot_id}`, `out_of_area_shown`.

## 7. Out of scope
- Vehicle type / open-now / price filters and the list view (E2, SPEC-002). The RPC already accepts `vehicle_type`.
- Lot detail screen and "Navigate" (E3, SPEC-003). E1 ends at the mini card → `/lot/:id`.
- Verified badge and live availability on pins (US-6.7, SPEC-006).
- Privacy policy content and the i18n framework (SPEC-005). E1 uses them.
- Address/place search, routing, background location, storing location history, iOS native app.

## 8. Test notes
**Mock GPS points** (approximate — QA to verify on the map before use)
| ID | Place | Lat, Lng | Purpose |
|---|---|---|---|
| MP-1 | Bãi Trước (Front Beach) | 10.3460, 107.0740 | Default centre, dense, tourists |
| MP-2 | Bãi Sau (Back Beach, Thùy Vân) | 10.3440, 107.0960 | Dense pins, clustering |
| MP-3 | Tượng Chúa Kitô | 10.3265, 107.0845 | Hilly, low accuracy (set accuracy 150 m) |
| MP-4 | City centre / Chợ Vũng Tàu | 10.3500, 107.0820 | Narrow streets |
| MP-5 | Offshore east of Bãi Sau | 10.3400, 107.1150 | Empty state at 1 km |
| MP-6 | HCMC District 1 | 10.7769, 106.7009 | Outside service area |

**Test data:** seed ≥ 60 lots around MP-2 (cap/cluster tests), a mix of vehicle types, 0 lots within 1 km of MP-5, ≥ 1 lot within 3 km of MP-5.

| TC | Story/AC | Case |
|---|---|---|
| TC-1.1.1 | 1.1 AC1 | Fresh install → S1 shown before OS prompt; no location call (check logs) |
| TC-1.1.2 | AC2 | Grant at MP-1 → centred, blue dot + accuracy circle |
| TC-1.1.3 | AC3 | "Not now" → default centre, banner, no OS prompt |
| TC-1.1.4 | AC4 | Deny once → banner; Enable re-prompts |
| TC-1.1.5 | AC5 | Android "Don't ask again" → opens app settings; Web blocked → instructions |
| TC-1.1.6 | AC6 | GPS off → banner; turn on → fix ≤ 5 s on resume |
| TC-1.1.7 | AC7/AC8 | Mock route MP-1→MP-4; dot moves; pan, then My location recenters |
| TC-1.1.8 | AC9 | No fix (indoor / mock disabled) → timeout handling after 10 s |
| TC-1.1.9 | AC10 | MP-6 → out-of-area banner, "Go to Vũng Tàu" |
| TC-1.1.10 | AC11 | Web Chrome + iPhone Safari over HTTPS; HTTP/unsupported → no error |
| TC-1.2.1 | 1.2 AC1/NFR-1 | MP-1 on 4G (and throttled) → pins ≤ 2 s |
| TC-1.2.2 | AC2 | Correct icon for motorbike / car / both |
| TC-1.2.3 | AC4 | MP-5 → empty state; Expand → 3 km results |
| TC-1.2.4 | AC5 | Airplane mode → error banner, pins kept; reconnect → auto retry |
| TC-1.2.5 | AC6 | Pan > 30% → button appears; no request on pan (network log); tap → reload |
| TC-1.2.6 | AC7/AC9 | MP-2 → clusters, cap hint at 50; zoom 17 → no clusters |
| TC-1.2.7 | AC8 | Tap pin → card with client-side distance; tap card → `/lot/:id` |
| TC-1.2.8 | DB | RPC: ordering, limit 50, radius clamp, `vehicle_type` filter, anon can execute, RLS on (SQL test) |
| TC-1.2.9 | PDPL | Inspect traffic: coordinates only in POST body, rounded to 4 decimals; no coordinates in analytics/Crashlytics; no table writes |
| TC-1.3.1 | 1.3 AC1 | MP-3 with 150 m accuracy / Android approximate → low-accuracy banner |
| TC-1.3.2 | AC2/AC3 | Adjust → move → Confirm → manual marker, lots reloaded |
| TC-1.3.3 | AC4 | Mock GPS moves while manual → no change; My location → back to GPS |
| TC-1.3.4 | AC5 | Cancel → unchanged |
| TC-1.3.5 | AC6 | Permission denied → manual position works |
| TC-1.3.6 | AC7 | Restart / reload → manual position cleared |
| TC-1.3.7 | AC2 | Long-press → adjust mode at the pressed point |

Devices: per the test-strategy matrix (low-end Android, mid Android, iPhone Safari, desktop Chrome).

## 9. Open questions (PO to decide)
1. Confirm defaults: radius 1/3/5 km, 50-pin cap, default centre Bãi Trước, service-area box, rounding to 4 decimals.
2. Consent (US-5.2) is planned for Sprint 3 but E1 ships in Sprint 1 — pull the minimal consent screen S1 into Sprint 1? (PDPL gap otherwise.)
3. Tile provider (kickoff action A7): MapTiler and Stadia free plans appear to be **non-commercial only** — verify current terms; acceptable for a free beta? Needs an ADR before Sprint 1.
4. Does Firebase Analytics need its own consent under PDPL (SPEC-005)?
5. Hide inactive/closed lots? `parking_lots` has no `status`/`is_active` column.
6. Manual position: persist on device across restarts, or session only (current assumption)?
7. Figma mockups owner and date (DoR blocker).

## 10. Change history
| Version | Date | Change | By |
|---|---|---|---|
| 0.1 | 2026-11-24 | Initial draft (drafted by Plan sub-agent, reviewed by Claude main agent) | Tech Lead |
