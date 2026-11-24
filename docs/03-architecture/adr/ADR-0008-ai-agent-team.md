# ADR-0008: Use a team of Claude Code sub-agents to assist development

- **Status:** Accepted
- **Date:** 2026-11-24
- **Decided in:** Chat with PO, 2026-11-24

## Context
The team wants to use agentic development. A single general assistant mixes roles and has no guardrails per role.

## Decision
Define role-based sub-agents in `.claude/agents/` (tech-lead, supabase-dev, flutter-dev, qa-engineer, scrum-master), each with limited tools and explicit hard limits. See [`docs/05-process/ai-agents.md`](../../05-process/ai-agents.md).

## Consequences
- Parallel work and focused output; agent definitions are versioned and reviewed like code.
- Agents never commit or deploy; humans approve via PR. Path/command limits rely on instructions + review.
- Each agent run costs usage — delegate substantial tasks only.
