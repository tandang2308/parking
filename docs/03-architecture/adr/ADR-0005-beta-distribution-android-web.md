# ADR-0005: Beta via Firebase App Distribution + Web, no store release

- **Status:** Accepted
- **Date:** 2026-11-24
- **Decided in:** MTG-2026-11-24-kickoff

## Context
Google Play costs $25 one-time; Apple Developer costs $99/year. MVP must be free.

## Decision
- Android beta via **Firebase App Distribution** (free).
- **Flutter Web** build on free static hosting (GitHub Pages / Netlify / Vercel) so iPhone users can try it.
- Store releases deferred to post-MVP (E11).

## Consequences
- Beta testers must be invited (no public discovery).
- Web build needs browser geolocation permission handling.
