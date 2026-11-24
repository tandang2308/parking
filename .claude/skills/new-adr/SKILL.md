---
name: new-adr
description: Create a new Architecture/Project Decision Record (ADR-nnnn) for ParkFinder from the template, with options researched and compared, and add it to the ADR index. Use when a significant technical, cost or process decision must be made or recorded.
argument-hint: "<decision title, e.g. 'map tile provider'>"
---

# /new-adr — record a decision

Decision topic: `$ARGUMENTS` (ask the user once if empty).

## Steps
1. Work on a branch: if on `main`, create `docs/ADR-<nnnn>-<short-slug>`.
2. Find the next number: highest `ADR-nnnn` in `docs/03-architecture/adr/README.md` + 1 (4 digits).
3. Delegate to the **tech-lead** agent with:
   - topic, ADR number, today's date, template `docs/templates/adr-template.md`,
   - output `docs/03-architecture/adr/ADR-<nnnn>-<kebab-slug>.md` + a row in `docs/03-architecture/adr/README.md`,
   - constraints: $0 MVP (ADR-0002), PDPL, the stack in `CLAUDE.md`; compare ≥ 2 real options (pros/cons, cost, limits, licence),
   - **Status must be `Proposed`** — only the Product Owner (Tan Dang) accepts it,
   - list facts that must be verified (current pricing/terms) as "To verify" — no invented numbers,
   - if it replaces an older ADR, do not edit the old one; note "Supersedes ADR-xxxx" in the new one.
4. If the topic needs current facts (pricing, licences, terms of service), research them with web search before or alongside the agent and pass the findings + source URLs to it.
5. Review: options are real, the recommendation follows from the context, nothing outside `docs/` changed.
6. Commit as `docs: propose ADR-<nnnn> <title>`, push, give the PR link. Ask the PO to decide: Accept → change Status to `Accepted` in the PR, or Reject.

## Output to the user
The recommendation in 2–3 lines, the options table, what the PO must decide, PR link.
