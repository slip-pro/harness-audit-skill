# Harness audit — example report

> Illustrative output for a mid-size project ("acme-app"). Numbers and paths are
> fictional but realistic; your report will be in the language you talk to Claude in.

## Headline numbers (before)

| Metric | Value | Threshold zone |
|---|---|---|
| Session preload (CLAUDE.md ×2 + memory index) | 4,120 words | worth a look |
| Rules | 14 files / 6,890 words | — |
| Skills | 23 (project 9, user 6, plugins 8) | — |
| Skill descriptions total | 11,300 chars | worth a look |
| Heaviest skill reference chain (depth 2) | `ship-release`: 38,400 words / 21 files | trouble |
| Duplicate basenames flagged | 4 (3 diverged) | trouble |

## Top findings

1. **`code-style.md` lives in 3 places and all 3 differ.** `.claude/rules/` (410 w),
   `docs/conventions/` (380 w), inside `ship-release` skill (505 w). The model gets three
   versions of the truth; only the skill copy mentions the linter that actually runs.
   → **MERGE** into `.claude/rules/code-style.md`; other two become links.
2. **`ship-release` chain drags 38k words, most of it upfront.** The skill links the full
   deployment runbook + rollback history. Needed only at the verify step.
   → **DEFER-LOAD**: split runbook reference into a "read at Phase 4" pointer.
3. **Word-limit and JSON-format requirements live as prose in 5 prompts.**
   → **HARDEN**: move to a PostToolUse hook / output schema; delete the prose.
4. **`legacy-api.md` rule references a service deleted in March.**
   → **REMOVE** (breaks nothing: no code references, no hook reads it).
5. **User memory: "always show steps" saved 8 months ago** still shapes every answer.
   → **REMOVE** from memory after owner confirms it's no longer wanted.

## Buckets

**KEEP** (9 items) — e.g. `.claude/rules/security.md`: enforced by review hook, referenced
by 3 skills, updated last month.
**MERGE** (3) — `code-style.md` ×3 → one home; `naming.md` ×2 → one home; test-fixture
guidance duplicated between two skills → extract to one rule.
**DEFER-LOAD** (4) — deployment runbook, API changelog, design tokens doc, QA checklist:
each moves from preload/skill-head to the phase that needs it.
**HARDEN** (5) — word limits ×2, JSON schema ×2, branch-name convention → hook.
**REMOVE** (3) — `legacy-api.md`, stale memory entry, unused `draft-email` skill
(no invocation in 6 months of transcripts).

## Projected after-state

| Metric | Before | After |
|---|---|---|
| Session preload | 4,120 w | 2,780 w (−33%) |
| Heaviest chain | 38,400 w | 9,200 w (−76%) |
| Diverged duplicates | 3 | 0 |
| Prose-only hard requirements | 5 | 0 |

## Receipt

Scanned: 2 CLAUDE.md, 14 rules, 23 skills (+descriptions), 2 settings files (key names
only), memory index, 4 hook registrations. Skipped: MCP instruction blocks (2 servers —
enumerate manually), plugin internals (read-only marketplace copies). Needs a human eye:
whether `naming.md` copies are truly the same rule or two audiences.

*No changes were made. Every arrow above is a proposal.*
