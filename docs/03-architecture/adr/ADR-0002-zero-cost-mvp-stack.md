# ADR-0002: Zero-cost MVP stack (Flutter + Supabase + OSM)

- **Status:** Accepted
- **Date:** 2026-11-24
- **Decided in:** MTG-2026-11-24-kickoff

## Context
The MVP must cost $0. We need maps, geospatial "nearby" queries, auth, file storage and an admin tool.

## Options considered
| Option | Pros | Cons |
|---|---|---|
| **A. Flutter + Supabase (PostGIS) + OSM tiles** | Free tier, real Postgres + PostGIS, auth/storage included, easy to migrate later | Free-tier limits; project pauses after 7 days idle |
| B. Flutter + Firebase (Firestore) + Google Maps | Mature, free mobile map SDK | Geo queries need geohash workarounds; Google Maps needs billing account (credit card) |
| C. Custom backend (NestJS/Go) on a VPS | Full control | VPS costs money; more work |

## Decision
Option **A**. Maps rendered with `flutter_map` using OSM tiles from a free plan (MapTiler or Stadia). Navigation via deep link to Google/Apple Maps. Crash/analytics via Firebase free.

## Consequences
- Need keep-alive job for Supabase and tile caching.
- Migration path: Supabase Pro or self-hosted Postgres without rewriting the app.
- Google Maps remains an option later (see future ADR if switched).
