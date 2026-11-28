# Test report — Task #39: customer-only label (BR-16), map label language (BR-17), attribution (BR-13) (Android)

| Field | Value |
|---|---|
| Story | US-1.2 AC8 / US-1.1 (SPEC-001 v0.4: BR-13, BR-16, BR-17, §6) · task #39 |
| Branch / commit | `feature/US-1.2-customers-only-label-language` @ `8c67229` (no PR yet) |
| Date | 2026-11-28 |
| Device | Android emulator Pixel_6 API 35, debug APK of this branch (installed 2026-11-28 15:10), en + vi (per-app locale) |
| Backend | **Local** Supabase (122 lots, 2 with `customers_only = true`: seed "TEST Bãi Trước chỉ khách" and OSM `way/1359979000`), reached through `adb reverse tcp:55321` |
| Map | Default build: OpenFreeMap vector tiles over the internet |
| Tester | `qa-tester` (AI sub-agent) |
| Test cases | docs/06-qa/test-cases/E1.md v0.3: TC-1.2.34, TC-1.1.33, TC-1.1.21, TC-1.2.7 (regression) |

Screenshots (file names quoted below) were kept locally in the QA scratch folder. They are **not** stored in the repo.

**How the run was set up**
- GPS with `adb emu geo fix` (MP-1 = 10.3460, 107.0740; near Bãi Sau 10.3435, 107.0920). App locale with `cmd locale set-app-locales … --locales vi|en`, then force-stop and relaunch.
- At the start, consent was `declined` (banner "Turn on location…"). I used Enable → Allow → "While using the app" to get a GPS position for card distances.
- Card text comes from the screen and from the uiautomator dump (semantics labels). Log means the app line `nearby_lots loaded …` / `Map style loaded in … ms` from `adb logcat`.
- I checked distances with my own haversine against lot coordinates from the local DB (read-only `select`).

## 1. Summary

| Result | Count | Cases |
|---|---|---|
| Pass | 3 | TC-1.2.34, TC-1.1.33, TC-1.2.7 |
| Fail | 1 | TC-1.1.21 (attribution is bottom-**right**, BR-13 v0.4 says bottom-left) |
| Blocked | 0 | — |
| Not run | 0 cases; parts not run: Web (all 4 cases also list Web), TC-1.1.21 with a non-default `TILE_ATTRIBUTION` build |

Extra regression check: map tiles render in en and in vi — **Pass**.

Automated: `flutter test test/lot_card_test.dart test/map_label_language_test.dart test/lots_geo_test.dart` → **61/61 passed** (run by me on 8c67229). It includes the automated-widget part of TC-1.2.34 (`TC-1.2.34 vi: customer-only lot shows the label under the name`, `… other lots have no label`, `BR-6: the pin style does not depend on customers_only`).

## 2. Results

| TC | Result | What I did | What I saw |
|---|---|---|---|
| TC-1.1.21 (P1) | **Fail** (position only) | Checked the attribution at zoom 15 with the banner shown (default centre, consent declined), at zoom 16 (GPS MP-1), at about zoom 18 with the mini card open, in adjust mode, with the "Showing nearest 50" chip, in en and in vi. | Text is exactly **"OpenFreeMap © OpenMapTiles Data from OpenStreetMap"** in every state and in both languages (not translated). It is never covered: not by the banner (`02-after20s.png`), the card (`05-en-customer-card.png`, `10-…`, `12-…`, `15-…`), the FAB or the adjust bar (`08-en-adjust-mode.png`). Semantics label = the same text. **But it sits bottom-right** (x 280–1080 px, y ≈ 2310 px), not bottom-left as BR-13 v0.4 requires. See **BUG-1**. Text from config: the default build shows the default value. I did not run a build with another `TILE_ATTRIBUTION`. |
| TC-1.2.34 (P2) | **Pass** (manual) + covered by `flutter test` | en, GPS MP-1: tapped the "TEST Bãi Trước chỉ khách" pin, then "TEST Bãi Trước 1". GPS near Bãi Sau: tapped the OSM lot `way/1359979000`. Then the same 3 pins in vi. | 1: card "TEST Bãi Trước chỉ khách" / **"Customers only"** (under the name) / "Motorbike, Car" / "120 m" (`05-en-customer-card.png`). The pin has the same style as the other motorbike + car pins (purple, 2 icons), only larger while selected (`04-cluster-tap.png` vs `05-…`). 2: "TEST Bãi Trước 1" / "Car" / "50 m", **no label** (`06-en-normal-card.png`). OSM lot: "Bãi đỗ xe (OSM way/1359979000)" / "Customers only" / "Car" / "100 m", normal blue car pin (`10-en-osm-customer-card.png`). 3 (vi): **"Chỉ dành cho khách"** / "Xe máy, Ô tô" / "120 m" (`12-vi-customer-card.png`). "TEST Bãi Trước 1" / "Ô tô" / "50 m", no label (`13-vi-normal-card.png`). OSM lot "Chỉ dành cho khách" / "Ô tô" / "100 m" (`15-vi-osm-customer-card.png`). Haversine: 120.5 m, 50.0 m, 96.7 m ✓. |
| TC-1.1.33 (P2) | **Pass** | 1) en: map at MP-1 (zoom 16 and ~18) and near Bãi Sau. 2) Switched the app to vi, force-stop, relaunched; the same views. 3) Looked for places with no English name in en. | en (`03-gps-mp1.png`, `09-en-baisau.png`): English names where OSM has one: "Coconut Bay", "…T BEACH" (Front Beach, partly under a cluster), "Triangle P…", "Vinh Nghiem Buddhist Temple", "Truong Vinh Ky Street", "Chau Thanh Secondary School", "Xom Luoi Market", "Thi Sach Street", "Su Van Hanh Street", "Ho Xuan Huong Street", "Vung Tau Bus Station", "Southern Youth Centre", "…Sen …e" (Bau Sen Lake). vi (`11-vi-mp1.png`, `14-vi-baisau.png`, `15-…`): the same places as "Vịnh Hàng Dừa", "…TRƯỚC" (Bãi Trước), "Công viên Tam…", "Chùa Vĩnh Nghiêm", "Trương Vĩnh Ký", "Trường Trung học cơ sở Châu Thành", "Chợ Xóm Lưới", "Thi Sách", "Sư Vạn Hạnh", "Hồ Xuân Hương", "…xe Vũng Tàu", "…àu …n" (Bàu Sen). No English name left in vi except names whose OSM local name is English (see O1). 3: en falls back to the local name, never empty: "Bà Triệu", "Lê Quý Đôn", "Lê Lợi", "Cảng tàu khách Vũng Tàu", "Đài liệt sĩ", "BÃI SAU", "KHU PHỐ 17". Log: `Map style loaded in 10128 ms` (en, first load) / `2149 ms` (vi). |
| TC-1.2.7 (P1, regression) | **Pass** (Android) | en, GPS MP-1. Tapped the pin "TEST Bãi Trước 1", then the card. | 1: pin highlighted (larger), card name + "Car" + "50 m" (BR-15 format; haversine 50.0 m) (`06-en-normal-card.png`). 2: detail screen titled "TEST Bãi Trước 1" with Back (`07-en-lot-detail.png`). On Android the route `/lot/:id` and the id are not visible; I only saw that the right lot opened. |
| Regression: tiles in en and vi | **Pass** | Cold start in en and in vi. | Vector tiles with roads, water, POIs and labels in both languages (`02-after20s.png`, `11-vi-mp1.png`). In en the first style load took 10 s (grey map with pins only, `01-launch-en.png`); see O3. |

## 3. Bugs

### BUG-1 — Tile attribution is bottom-right, not bottom-left
- **Reference:** TC-1.1.21; SPEC-001 BR-13 (v0.4, D5).
- **Severity:** Minor. The attribution is always visible and the text is correct; only its position differs from the spec.
- **Steps to reproduce:** Open the map (any state, en or vi) and look at the bottom of the screen.
- **Expected (BR-13):** "the attribution must always be visible (**bottom-left**; never covered by card, banner or FAB) and is not translated."
- **Actual:** The attribution box is right-aligned at the bottom (x 280–1080 px on a 1080 px screen), directly under the "My location" FAB. Bottom-left is new in v0.4, so the earlier position was not wrong before.
- **Screenshots:** `02-after20s.png`, `05-en-customer-card.png`, `08-en-adjust-mode.png`.

## 4. Observations

- **O1 (BR-17, not a bug):** In vi, "Modern Art Sculpture Park" (near Bãi Trước), "Petro House Vũng Tàu", "New Wave Hotel" and "Circle K" stay in English (`12-vi-customer-card.png`). I downloaded the public OpenFreeMap z14 tile 14/13065/7718 (the tile the app shows there). It holds only the string "Modern Art Sculpture Park" for that park, with no Vietnamese variant. So the OSM local `name` is itself English, and BR-17 (vi → `name`) is followed.
- **O2 (US-1.2, vi text, Minor):** In vi the chip "Đang hiển thị 50 bãi gần nhất — phóng to để xem …" is cut off at its right edge ("…để xen", `14-vi-baisau.png`, `15-vi-osm-customer-card.png`). The en text fits. This is not part of task #39.
- **O3 (performance, info):** On the first cold start in en the map stayed grey for about 10 s (`Map style loaded in 10128 ms`, `01-launch-en.png`). Later loads took 0.6–2.1 s. This may be the first style download plus the new per-language style rewrite, or emulator network. It needs a check on a real device.
- **O4 (test state):** The run changed the app's consent from `declined` to `granted`, and FINE location is now granted. I did not reset this.

## 5. Open questions

- **Q1 (BR-13):** Should the attribution move to bottom-left (as in BR-13 v0.4), or should the spec say bottom-right (the current layout, under the FAB)? The PO decides.
- **Q2 (TC-1.2.7, Android):** The `/lot/:id` route is not visible on Android. Is checking the detail title enough, or should the placeholder show the id for QA?

## 6. Environment after the run

App locale set back to `en` (`get-app-locales` → `[en]`). `adb reverse` is still `tcp:55321 → tcp:55321`. GPS is back at MP-1. The app was force-stopped. Consent stays `granted` (O4).
