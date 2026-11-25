# ParkFinder app (Flutter, Android + Web)

Flutter client for ParkFinder Vũng Tàu. Current state: app skeleton + map tile spike
(ADR-0009 validation gate, see `docs/03-architecture/spikes/ADR-0009-tile-spike.md`) +
location consent screen S1 and vi/en localisation (US-1.4) + my position on the map (US-1.1) +
nearby parking lots as pins (US-1.2).

Requires Flutter 3.38.x stable. All commands run from this `app/` folder.

## Run
```sh
flutter pub get
flutter run -d chrome                 # Web (debug)
flutter run -d web-server --web-port 8080   # Web (debug) if Chrome fails to launch on Windows
                                      # ("Failed to launch browser") — then open http://localhost:8080 yourself
flutter run -d <android-device-id>    # Android (debug); list devices with `flutter devices`
flutter run --profile -d <device-id>  # Profile mode, for performance/FPS checks
```

## Map tile config (`--dart-define`, ADR-0009 decision 3)
| Key | Default | Meaning |
|---|---|---|
| `TILE_RENDERER` | `vector` | `vector` (flutter_map_vector_tiles) or `raster` (flutter_map TileLayer) |
| `TILE_STYLE_URL` | `https://tiles.openfreemap.org/styles/liberty` | MapLibre style for `vector` |
| `TILE_RASTER_URL` | _(empty)_ | `{z}/{x}/{y}` URL template for `raster` (must be set when using raster) |
| `TILE_ATTRIBUTION` | `OpenFreeMap © OpenMapTiles Data from OpenStreetMap` | Always-visible attribution (SPEC-001 BR-13) |
| `TILE_MAX_ZOOM` | `18` | Maximum map zoom |

Example (raster, **local development only** — OSM standard tiles must never ship, ADR-0009 decision 2):
```sh
flutter run -d chrome --dart-define=TILE_RENDERER=raster \
  --dart-define=TILE_RASTER_URL=https://tile.openstreetmap.org/{z}/{x}/{y}.png \
  "--dart-define=TILE_ATTRIBUTION=© OpenStreetMap contributors"
```
No API keys are needed for the default provider. Never put secrets in `--dart-define` values.

## Supabase / nearby lots (US-1.2, SPEC-001 §5)
Lots come (via the pure-Dart `supabase` client, MIT — ADR-0012) from the Supabase RPC `nearby_lots` (`POST /rest/v1/rpc/nearby_lots`, coordinates in the
body only, rounded to 4 decimals, BR-10). Connection settings are passed with `--dart-define`:

| Key | Default | Meaning |
|---|---|---|
| `SUPABASE_URL` | _(empty)_ | Project URL, e.g. `https://<project-ref>.supabase.co` (local stack: `http://127.0.0.1:55321`) |
| `SUPABASE_ANON_KEY` | _(empty)_ | The public **anon** key only — never the service-role key |

If either value is missing the app still starts; every lot load then fails and the
"Can't load parking lots" banner is shown. Never commit the values (no keys in code, `.env` or docs).

**Recommended: a settings file outside the repo.** Long commands pasted into the terminal often break
across lines and silently drop the `--dart-define`s (the console then logs
`Supabase not configured`). Create `D:\Projects\parking-local\supabase.json` (any path **outside** the
repo, so it can never be committed):
```json
{ "SUPABASE_URL": "https://<project-ref>.supabase.co", "SUPABASE_ANON_KEY": "<anon key>" }
```
Get the anon key in the Supabase dashboard → Project Settings → API Keys (`anon` / publishable key).
Then run (PowerShell, Web):
```powershell
flutter run -d web-server --web-port 8080 --dart-define-from-file=D:\Projects\parking-local\supabase.json
```
Alternative without a file:
```powershell
flutter run -d web-server --web-port 8080 "--dart-define=SUPABASE_URL=https://<project-ref>.supabase.co" "--dart-define=SUPABASE_ANON_KEY=<anon key>"
```
The same flags (`--dart-define-from-file` or `--dart-define`) work for `flutter build web --release`
and `flutter build apk`.

Behaviour notes: lots load only on the BR-3 triggers (first position, "My location", "Search this
area", Retry/Expand, and one automatic retry when the connection comes back — Web: browser `online`
event, Android: own `EventChannel` `vn.parkfinder/connectivity` in `MainActivity.kt`, no plugin — ADR-0012). Pan/zoom never loads. Clustering (BR-4) is implemented in
`lib/features/lots/lot_clustering.dart` (`flutter_map_marker_cluster` 8.2.2 requires
`latlong2 ^0.9.1`, the app uses `^0.10.1`). Tapping the mini card opens `/lot/:id`, a placeholder
until US-3.1. Debug/profile builds log `nearby_lots loaded count=… radius_m=… duration_ms=…`
(NFR-1 timer, never coordinates).

## Location consent (US-1.4, SPEC-001)
The consent screen S1 is shown before the map on first launch. The answer (`granted` /
`declined`, consent version, UTC timestamp) is stored on the device only
(`shared_preferences`: Android SharedPreferences / Web localStorage, keys `location_consent.*`).
The OS/browser location permission is requested only after "Allow".

| Key | Default | Meaning |
|---|---|---|
| `CONSENT_VERSION` | `1` | Consent notice version. A stored answer with a lower version shows S1 again (AC6). QA: build with `--dart-define=CONSENT_VERSION=2` for TC-1.4.4 |

To see S1 again while developing: clear app data (Android) or site data / localStorage (Web).

## Localisation (vi + en)
Flutter gen-l10n: ARB files in `lib/l10n/` (`app_en.arb` is the template), config in `l10n.yaml`,
generated code in `lib/l10n/generated/` (regenerated by `flutter pub get` / `flutter gen-l10n`;
keep it committed). Keys and texts come from SPEC-001 §6. The app follows the device/browser
language; any language other than vi/en falls back to vi.

## Test and analyse
```sh
flutter analyze
flutter test
```
Tests never hit the network (the style loader is injected).

## Build
```sh
flutter build web --release   # output: build/web
flutter build apk --debug     # needs the Android SDK
flutter build apk --release   # needs the Android SDK (signing not set up yet)
```
