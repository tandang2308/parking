# ParkFinder Vung Tau — Project Documentation

> Working name: **ParkFinder**. App to find parking lots near the user's current position.
> Pilot city: **Vũng Tàu** (now part of Ho Chi Minh City since 07/2025). Other cities later.

All project knowledge lives here, versioned in Git next to the code. If it isn't written here, it wasn't decided.

## Structure

| Folder | What goes there | Owner |
|---|---|---|
| [`01-product/`](01-product/) | Vision, PRD, product backlog, roadmap | Product Owner |
| [`02-specs/`](02-specs/) | Feature specifications (one per feature / epic) | PO + Tech Lead |
| [`03-architecture/`](03-architecture/) | System design, data model, API, **ADRs** (decision records) | Tech Lead |
| [`04-meetings/`](04-meetings/) | Minutes of every Scrum event and ad-hoc meeting | Scrum Master |
| [`05-process/`](05-process/) | Scrum working agreement, DoR/DoD, conventions | Scrum Master |
| [`06-qa/`](06-qa/) | Test plans, test cases, field-test reports | QA |
| [`templates/`](templates/) | Copy these to create new docs | Everyone |

## Traceability — ID scheme

Every artifact has an ID so we can trace *idea → decision → spec → code → test*.

| Artifact | ID format | Example |
|---|---|---|
| Epic | `E<n>` | `E6` Owner Portal |
| User story | `US-<epic>.<n>` | `US-6.2` Owner claims a lot |
| Spec | `SPEC-<nnn>` | `SPEC-006` Owner Portal |
| Architecture decision | `ADR-<nnnn>` | `ADR-0002` Zero-cost stack |
| Meeting minutes | `MTG-<yyyy-mm-dd>-<type>` | `MTG-2026-11-24-kickoff` |
| Test case | `TC-<epic>.<story>.<n>` | `TC-6.2.1` |

**Linking rules**
- Git branch: `feature/US-6.2-claim-lot`
- Commit message: `US-6.2: add claim lot screen`
- Pull request: must reference the story ID and the spec (see `.github/pull_request_template.md`).
- Specs reference stories and ADRs; meeting minutes reference any decision/ADR they produce.
- Documents are **never deleted** — mark them `Superseded by ADR-xxxx` / `Deprecated` instead.

## Index

- Product: [PRD](01-product/PRD.md) · [Backlog](01-product/backlog.md) · [Roadmap](01-product/roadmap.md)
- Architecture: [Overview](03-architecture/architecture.md) · [ADR log](03-architecture/adr/README.md)
- Specs: [Spec index](02-specs/README.md)
- Meetings: [Meeting index](04-meetings/README.md)
- Process: [Scrum working agreement](05-process/scrum.md)
- QA: [Test strategy](06-qa/test-strategy.md)
- [Glossary](glossary.md)
