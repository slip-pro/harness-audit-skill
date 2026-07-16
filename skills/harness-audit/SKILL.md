---
name: harness-audit
description: Audit your Claude Code harness — map every instruction the model carries (CLAUDE.md, rules, skills, commands, agents, hooks, memory, settings, MCP), find duplicates and bloat, and get a prioritized cleanup plan. Use when the model "got worse", before switching models, or as periodic maintenance. Read-only — reports and proposes, never changes anything.
---

# harness-audit

Your harness is everything wrapped around the model that you control: instructions,
rules, skills, memory, hooks, permissions. It grows one patch at a time and no single
screen shows it whole. This skill makes it visible, then proposes a cleanup — map first,
clean second.

**Invariants — read before doing anything:**
- **Read-only.** You never edit, move, or delete anything during the audit. Every change
  is a separate action the owner takes after reading the report.
- **No secret values.** Inventory settings and configs by key names and sizes only.
- **Report in the language of the conversation.** The skill text is English; the report
  belongs to the user.

## Phase 1 — MAP (build the inventory)

1. Run the deterministic collector (requires bash ≥ 4):
   `bash .claude/skills/harness-audit/scripts/inventory.sh <project-path>` — the path
   after the standard install; if the repo is kept elsewhere, use its
   `scripts/inventory.sh` path. `HARNESS_AUDIT_EXTRA_SKILL_DIRS=/path1:/path2` covers
   non-standard skill layouts.
2. Read its output and extend it with what a script cannot see. Enumerate every surface,
   and for each element record: **where it lives / when it loads / how big it is**:
   - `CLAUDE.md` — project, `CLAUDE.local.md`, user `~/.claude/CLAUDE.md`, and their
     `@`-imports (all load every session — this is the preload).
   - Rules directories (project `.claude/rules/`, user, or repo conventions).
   - Skills — project, user, and plugin skills; frontmatter `description:` lines are the
     discovery budget the model spends to pick a skill.
   - Commands, agents, hooks (registration in `settings.json` — count, don't read values),
     auto-memory (`MEMORY.md` index + files), permission lists, MCP servers and their
     instruction blocks.
   - A surface that doesn't exist in this setup is noted and skipped — never an error.
3. Distinguish **text vs enforced checks**: a polite instruction in prose and a hook/
   permission/schema that actually blocks are different species. Tag each element.
4. **Tool surface (you observe this, the script cannot).** The script sees MCP server
   names in config; you carry the *live* tool surface this session actually loaded. Record:
   how many tools are available, how many load upfront vs. are deferred (pulled in on
   demand, e.g. via a tool-search mechanism), which MCP servers contribute how many tools,
   and whether each ships an instruction block. Tool definitions are a first-class context
   cost, not free plumbing — inventory them like any other surface.

## Phase 2 — ANALYZE (find the junk)

Work through five lenses, citing file paths and numbers for every finding:

1. **Duplicates and drift.** Same rule living in several places; same-name files with
   diverging content (the script flags candidates — verify each by reading both versions;
   same name with different purpose is NOT a duplicate). Each real copy is a fork of the
   truth: one gets fixed, the others rot.
2. **Load-time misplacement (the progressive-disclosure test).** What loads at session
   start but is only needed for one task type? What does each skill drag in through its
   reference chain (the script measures words per chain)? Big libraries are fine —
   everything loading at once is not. A healthy surface loads a *pointer* and opens the
   detail on demand (the way skills are meant to work); an unhealthy one inlines the whole
   procedure into `CLAUDE.md` or a skill head, so it's paid for every session whether the
   task needs it or not. Flag front-loaded content that should sit behind a link.
3. **Budget pressure.** Total preload words; sum of skill descriptions vs the discovery
   surface; the single heaviest routes. Report raw numbers and compare against the
   thresholds table in the repo README (they age — the numbers don't).
4. **Stale, unenforced, and compaction-fragile.** Rules referencing tools/files that no
   longer exist; hard requirements (word limits, output formats) living as prose that
   should be hooks, schemas, or permission rules instead. And separate **critical rules
   from compaction-survivable ones**: an instruction the model must never drop (a safety
   invariant, a hard constraint) belongs somewhere permanent — a hook, a permission, an
   always-loaded config line — not in prose that a mid-session context compaction can
   summarize away. Flag critical instructions that survive only as long as the raw text
   stays in the window.
5. **Tool surface.** More tools is not more capability — overlapping or redundant tools
   degrade selection, and every definition spends context whether or not it's used. From
   the live surface (MAP step 4): which tools overlap or duplicate each other's job? Which
   servers are subscribed but unused here? Which heavy schemas load upfront when they're
   needed for one task type only? The fix is a minimal, non-overlapping set: drop unused
   servers, prefer deferred/on-demand tool loading over loading everything upfront, and
   for MCP-heavy setups consider driving the server through code execution instead of
   exposing every tool as a direct call. Tools should return only the signal the task needs.

## Phase 3 — REPORT (verdict first, details last)

Write for a human who hasn't seen the audit. Every finding is a short story in plain
language — what's happening → why it hurts → what to do → what it saves. The analysis
lenses (keep / merge / defer-load / harden / remove) stay internal to Phase 2; in the
report they become ordinary verbs inside sentences, never headline codes like "MERGE ×3".
Structure, top to bottom:

1. **TL;DR (≤5 lines)** — one-phrase verdict (healthy / needs cleanup / cluttered), the
   single most telling number, and the top 3 actions with their expected payoff.
2. **Health board** — six axes as traffic lights (green / yellow / red), one line of
   "why" per axis: session preload, duplicate & drifted rules, skill catalog
   (descriptions budget), heaviest load routes, stale or unenforced rules, tool surface
   (count, overlap, upfront vs. deferred).
3. **Findings by priority** — critical first. Each: a short paragraph (what → why it
   hurts → proposal → expected saving); paths and numbers are the evidence, not the
   headline.
4. **What's healthy** — what to leave alone and why. Earns trust (the report doesn't
   only complain) and stops the next audit from re-litigating settled calls.
5. **Cleanup plan** — proposed steps in execution order + a before → after table of the
   headline numbers if every proposal is accepted.
6. **Appendix** — full inventory numbers and the receipt: what was scanned, what was
   skipped and why, what needs a human eye. The owner decides; you propose.

Offer to re-run the audit after cleanup to verify the before/after delta — and suggest
scheduling it as periodic maintenance (monthly, or before every model switch).
