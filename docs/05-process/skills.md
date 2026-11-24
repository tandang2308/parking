# Skills (slash commands)

| Status | v0.1 · 2026-11-24 · Owner: Scrum Master (Khoi Dang) |
|---|---|

Skills are reusable recipes in `.claude/skills/<name>/SKILL.md`. Type `/<name>` in Claude Code to run one. They turn repeated, multi-step work into one command and encode lessons learned.

| Command | What it does | Uses agent | Who may trigger |
|---|---|---|---|
| `/minutes <type> <notes>` | Notes → minutes `MTG-<date>-<type>` from the right template, index/backlog/roadmap updates, PR | scrum-master | Anyone |
| `/new-adr <title>` | New ADR (next number, options compared, Status = Proposed), index row, PR for PO decision | tech-lead | Anyone (PO accepts) |
| `/deploy-db` | Merged migrations → local tests → dry-run → confirm → cloud push → verify via API | — (main agent) | User only (`disable-model-invocation`) |

## Skill vs agent vs CLAUDE.md
| | CLAUDE.md | Agent (`.claude/agents/`) | Skill (`.claude/skills/`) |
|---|---|---|---|
| Is | Project rules, always loaded | A **who**: role, tools, limits | A **how**: a step-by-step procedure |
| Triggered | Automatically | By the main agent (delegation) | By you (`/name`) or by Claude when the description matches |
| Example | "Never commit secrets" | qa-engineer | `/deploy-db` |

## Writing a new skill
1. Create `.claude/skills/<name>/SKILL.md` with frontmatter `name`, `description` (what + when), optional `argument-hint`, and `disable-model-invocation: true` for risky actions.
2. Body = numbered steps; use `$ARGUMENTS` for the text after the command.
3. Commit via PR like any other change.
