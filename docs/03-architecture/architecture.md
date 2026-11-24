# Architecture Overview (MVP)

| Status | Draft · v0.1 · 2026-11-24 · Owner: Tech Lead |
|---|---|

## 1. Components
```
 ┌──────────────────────┐        ┌──────────────────────────────────┐
 │ Flutter app          │  HTTPS │ Supabase (free tier)             │
 │  - Driver mode       │───────▶│  - PostgreSQL + PostGIS          │
 │  - Owner mode        │        │  - Auth (email / Google)         │
 │  Android + Web       │        │  - Storage (lot photos, docs)    │
 └─────────┬────────────┘        │  - Auto REST API + RPC functions │
           │                     │  - Row Level Security            │
           │ map tiles           └──────────────▲───────────────────┘
           ▼                                    │
 ┌──────────────────────┐              ┌────────┴─────────┐
 │ OpenFreeMap vector   │              │ Supabase Studio  │
 │ tiles (ADR-0009)     │              │ = Admin panel    │
 └──────────────────────┘              └──────────────────┘
 Navigation → deep link to Google Maps / Apple Maps app
 Crash/analytics → Firebase Crashlytics + Analytics
```

## 2. Tech choices
See ADRs: [ADR-0002](adr/ADR-0002-zero-cost-mvp-stack.md), [ADR-0003](adr/ADR-0003-supabase-studio-as-admin.md).

| Layer | Choice |
|---|---|
| Mobile/Web client | Flutter, `flutter_map` |
| Backend | Supabase (Postgres, PostGIS, Auth, Storage) |
| Admin | Supabase Studio |
| CI/CD | GitHub Actions |
| Beta distribution | Firebase App Distribution (Android), static hosting (Web) |

## 3. Data model (draft — to be detailed in SPEC-004 / SPEC-006)
| Table | Key fields |
|---|---|
| `profiles` | id, role (`driver` / `owner` / `admin`), display_name, locale |
| `parking_lots` | id, name, location (`geography(Point)`), address, vehicle_types[], price_motorbike, price_car, opening_hours, capacity, source (`osm` / `survey` / `owner`), last_verified_at, is_verified |
| `lot_photos` | id, lot_id, storage_path |
| `lot_owners` | id, lot_id, owner_id, status (`pending` / `verified` / `rejected`), documents, reviewed_by, reviewed_at |
| `lot_availability` | lot_id, status (`available` / `almost_full` / `full`), updated_at, updated_by |

Key RPC: `nearby_lots(lat, lng, radius_m, vehicle_type)` → max 50 lots ordered by distance (PostGIS `ST_DWithin` + `ST_Distance`); returns `lot_lat`/`lot_lng` (output names cannot repeat the input params). Full definition: [SPEC-001 §5](../02-specs/SPEC-001-location-and-map.md#5-data--api).

## 4. Security
- App uses only the public `anon` key; **never** ship the service key.
- Row Level Security: owners edit only lots where `lot_owners.status = 'verified'` and `owner_id = auth.uid()`.
- Location is not stored server-side unless needed (PDPL).

## 5. Known free-tier limits
| Item | Limit | Mitigation |
|---|---|---|
| Supabase | 500 MB DB, 1 GB storage, pauses after 7 days idle | Keep-alive GitHub Action, compress images |
| Map tiles (OpenFreeMap, ADR-0009) | No quota, but no SLA (donation-funded) | Tile URL/style in config; fallback 4a/4b in ADR-0009; on-device caching |
| GitHub Actions | 2,000 min/month (private repo) | Cache dependencies, run on PR only |
