# ParkFinder app (Flutter, Android + Web)

Flutter client for ParkFinder Vũng Tàu. Current state: app skeleton + map tile spike
(ADR-0009 validation gate, see `docs/03-architecture/spikes/ADR-0009-tile-spike.md`).

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
