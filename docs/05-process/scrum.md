# Scrum Working Agreement

| Status | v0.1 · 2026-11-24 · Owner: Scrum Master · Ref: ADR-0001 |
|---|---|

## Roles
| Role | Person | Responsibility |
|---|---|---|
| Product Owner | Tan Dang | Owns backlog & priorities, accepts work, writes/approves specs |
| Scrum Master | _TBD_ | Facilitates events, removes blockers, keeps minutes in `docs/04-meetings` |
| Developers | Tech Lead, Devs, QA | Build, test, deliver Increment; Tech Lead owns architecture & ADRs; QA owns test strategy |

## Events (2-week sprint)
| Event | When | Timebox | Output (documented) |
|---|---|---|---|
| Sprint Planning | Day 1 | 2–4h | Sprint Goal + Sprint Backlog → planning minutes |
| Daily Scrum | Daily, fixed time | 15 min | Blockers/decisions → `daily-notes.md` only if needed |
| Backlog Refinement | Mid-sprint | 1–2h | Stories Ready, specs updated → refinement minutes |
| Sprint Review | Last day | 1–2h | Demo on real devices, PO acceptance, backlog changes → review minutes |
| Retrospective | Last day | 1h | Improvement actions → retro minutes |

## Definition of Ready (DoR)
- [ ] Story follows "As a…, I want…, so that…"
- [ ] Acceptance criteria written in the related SPEC
- [ ] UI mockup linked (Figma) if UI is involved
- [ ] Estimated by the team
- [ ] Dependencies resolved or planned

## Definition of Done (DoD)
- [ ] Code reviewed and merged to `main` via PR referencing the story ID
- [ ] Unit/widget tests pass in CI
- [ ] QA tested on Android (incl. a low-end device) and Web
- [ ] Spec / architecture docs updated if behaviour or design changed
- [ ] Deployed to staging
- [ ] PO accepted

## Git conventions
- Branch: `feature/US-x.y-short-name`, `fix/US-x.y-short-name`
- Commit: `US-x.y: short description`
- PR: fill in the template; link story, spec, ADR if any
