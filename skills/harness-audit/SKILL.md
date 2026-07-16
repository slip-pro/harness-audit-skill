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

## Phase 2 — ANALYZE (find the junk)

Work through four lenses, citing file paths and numbers for every finding:

1. **Duplicates and drift.** Same rule living in several places; same-name files with
   diverging content (the script flags candidates — verify each by reading both versions;
   same name with different purpose is NOT a duplicate). Each real copy is a fork of the
   truth: one gets fixed, the others rot.
2. **Load-time misplacement.** What loads at session start but is only needed for one
   task type? What does each skill drag in through its reference chain (the script
   measures words per chain)? Big libraries are fine — everything loading at once is not.
3. **Budget pressure.** Total preload words; sum of skill descriptions vs the discovery
   surface; the single heaviest routes. Report raw numbers and compare against the
   thresholds table in the repo README (they age — the numbers don't).
4. **Stale and unenforced.** Rules referencing tools/files that no longer exist; hard
   requirements (word limits, output formats) living as prose that should be hooks,
   schemas, or permission rules instead.

## Phase 3 — REPORT (buckets, not essays)

Produce a single report with:

1. **Headline numbers** — before-state: preload words, skill count, description chars,
   duplicates found, heaviest chain.
2. **Findings in five buckets**, each item = path + evidence + one-line proposal:
   - **KEEP** — earning its place; say why, so the next audit doesn't re-litigate it.
   - **MERGE** — duplicates → one home, one owner; name which copy survives.
   - **DEFER-LOAD** — useful but loading too early → move to the phase that needs it.
   - **HARDEN** — prose requirement → mechanical check (hook / schema / permission).
   - **REMOVE** — no evidence it still helps; note what breaks if you're wrong.
3. **Projected after-state** — the same headline numbers if all proposals are accepted.
4. **Receipt** — what was scanned, what was skipped and why, what needs a human eye.
5. Top 3-5 findings first, in plain language. The owner decides; you propose.

Offer to re-run the audit after cleanup to verify the before/after delta — and suggest
scheduling it as periodic maintenance (monthly, or before every model switch).
