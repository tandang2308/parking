# ADR-0012: Only permissive open-source licences for dependencies

- **Status:** Accepted
- **Date:** 2026-11-25
- **Decided in:** PO review of PR #27 (US-1.2), in chat 2026-11-25
- **Deciders:** Tan Dang (PO)

## Context
ADR-0002 requires a $0 stack, and the `flutter-dev` agent rule says "free, non-GPL packages only". While building US-1.2 (PR #27), `supabase_flutter` and `connectivity_plus` pulled in three **MPL-2.0** packages (`dbus`, `nm`, `gtk`). These are Linux-desktop-only and are not compiled into our Android or Web builds. MPL-2.0 is a weak copyleft licence: it is not GPL, but modified MPL files must be published, and it complicates a future licence review (e.g. for an app-store release or a commercial partner). The rule "non-GPL" did not say what to do with MPL, LGPL or other copyleft licences.

## Options considered
| Option | Pros | Cons |
|---|---|---|
| A. Allow anything that is not GPL (status quo) | No package changes | MPL/LGPL/EPL allowed by accident; unclear for reviewers |
| B. Allow MPL only when the package is not compiled into a shipped platform | Keeps `supabase_flutter` / `connectivity_plus` | Needs per-platform analysis on every upgrade; easy to get wrong |
| C. **Permissive licences only, for the whole dependency tree, on every platform** | Simple, checkable rule; no copyleft obligations | Some convenience packages are excluded; small amounts of own code instead (e.g. an Android connectivity channel) |

## Decision
**Option C.** Every package in `app/pubspec.lock` (direct and transitive, all platforms) must use a permissive licence: **MIT, BSD-2-Clause, BSD-3-Clause, Apache-2.0, ISC, zlib** (or an equivalent permissive licence approved by the Tech Lead). **Not allowed:** GPL, LGPL, AGPL, MPL, EPL, CDDL, SSPL, or packages with no licence. The same rule applies to the database side (SQL extensions, import scripts) where a licence applies.

## Consequences
- US-1.2 replaces `supabase_flutter` with a pure-Dart Supabase/PostgREST client and `connectivity_plus` with a small own Android platform channel (PR #27).
- Every PR that adds or upgrades a dependency lists the new packages with their licences; the reviewer checks `pubspec.lock`.
- `.claude/agents/flutter-dev.md` and `docs/05-process/ai-agents.md` now point to this ADR (same PR).
- Follow-up idea: a CI step that fails on non-permissive licences in `pubspec.lock`.
