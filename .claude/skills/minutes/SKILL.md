---
name: minutes
description: Turn rough meeting notes into ParkFinder meeting minutes (MTG-yyyy-mm-dd-type) using the project templates, update the meetings index, backlog and roadmap if decisions require it. Use when the user pastes meeting notes or asks to record a meeting or decisions.
argument-hint: "<type: planning|review|retro|refinement|adhoc|po-decisions> <notes...>"
---

# /minutes — record a meeting

Input: `$ARGUMENTS` (first word = meeting type, the rest = notes). If the type or notes are missing, ask the user once for them.

## Steps
1. Work on a branch: if on `main`, create `docs/minutes-<yyyy-mm-dd>-<type>`.
2. Delegate to the **scrum-master** agent with:
   - meeting type, today's date, the raw notes verbatim,
   - the template to use: `planning` → `docs/templates/sprint-planning-template.md`, `review` → `sprint-review-template.md`, `retro` → `retrospective-template.md`, anything else → `meeting-minutes-template.md`,
   - output path `docs/04-meetings/sprint-<nn>/<yyyy-mm-dd>-<type>.md` (current sprint from `docs/01-product/roadmap.md`; Sprint 0 = `sprint-00`),
   - people: PO = Tan Dang, Scrum Master = Khoi Dang (`docs/05-process/scrum.md`); never invent attendees, decisions or dates — unknown → `_TBD_`,
   - update the index in `docs/04-meetings/README.md`; update `docs/01-product/backlog.md` / `roadmap.md` only for decisions that change them.
3. Review the agent's output yourself: every decision has an ID (D1…) and a ref (ADR/SPEC/US); every action item has owner + due date; nothing invented.
4. If a decision is significant (architecture, stack, cost, process), tell the user it also needs an ADR and suggest `/new-adr <title>`.
5. Commit as `docs: add MTG-<date>-<type> minutes`, push the branch, and give the user the PR link. Do not merge.

## Output to the user
Short summary: decisions, action items (owner, due), files changed, PR link.
