# Harness audit — example report

> Illustrative output for a mid-size project ("acme-app"). Numbers and paths are
> fictional but realistic. The owner ran `/context` and `/doctor` and shared both, so
> the cost figures below are real tokens, not estimates. Your report will be in the
> language you talk to Claude in.

## TL;DR

**Verdict: needs cleanup.** `/context` shows **31,200 tokens** committed before the first
message — 15% of the window — and the biggest offenders aren't size, they're conflicts: two
rules give opposite instructions on commit messages, and a skill points at a runbook that was
deleted in March. Three moves fix most of it:

1. Resolve the commit-message contradiction (two rules, opposite orders) → the model stops
   guessing which one wins.
2. Fix or drop the 3 broken references → instructions stop pointing at deleted files.
3. Defer the release runbook out of the preload → −6,800 tokens on every non-release task.

## What `/doctor` already flags

The platform's own pass found three free wins — do these first, no judgement required:

- **Skill listing overran its budget.** 34 skills, listing at ~118% of the allowance —
  Claude Code is silently truncating the least-used descriptions, so some skills have gone
  undiscoverable. `/doctor` names `data-export` and `pdf-stamp` as the ones being cut.
- **2 MCP servers unused this session** (`figma`, `sentry`) — ~4,100 tokens of tool schemas
  loaded for zero calls. Disable them for projects that don't touch design or error triage.
- **CLAUDE.md has ~600 words of content derivable from the repo** (directory listing, the
  test command already in `package.json`). Trim per `/doctor`'s suggestion.

## What `/doctor` can't see — findings by priority

**1. Two rules disagree on commit messages, and the model can't tell which wins.** 🔴
`.claude/rules/git.md` says *"commit messages in imperative mood, no body"*; the `ship-release`
skill's embedded checklist says *"every commit needs a body explaining why"*. Both load, they
contradict, and which one the model follows depends on reading order. **Proposal:** pick one
home (the rule), delete the directive from the skill, link to the rule. Contradictions are the
one failure a token count and `/doctor` both miss — nothing catches them but reading.

**2. Three references point at files that no longer exist.** 🔴
`onboarding.md` links `docs/deploy-runbook.md` (deleted in March), `security.md` links a
`scripts/scan.sh` that was renamed to `audit.sh`, and CLAUDE.md `@`-imports `~/.claude/team.md`
which isn't there. Each reads as a live instruction and silently resolves to nothing.
**Proposal:** repoint the two that moved, delete the one that's gone. The inventory script
lists all three with their source lines.

**3. The code-style rule lives in three places, and they've drifted.** 🟡
`.claude/rules/code-style.md` (410 w), `docs/conventions.md` (380 w), and a copy inside
`ship-release` (505 w) — only the last mentions the linter that actually runs. Fixes land in
one copy and rot in the others. **Proposal:** keep the rule as the single home; replace the
other two with links.

**4. Starting a release drags in a small book.** 🟡
`/context` shows the preload at 8,900 tokens; ~6,800 of it is the deployment runbook and
rollback history linked from `ship-release`'s head — needed only at the verify step, if at all,
yet paid every session. `/doctor` flags bloat *inside* CLAUDE.md, but not this: the weight sits
in a skill's reference chain, not in the preload file itself, so it stays under the radar until
you trace what the route drags in. **Proposal:** move it behind a "read at verify" pointer.
Preload drops 8,900 → ~2,100 tokens with nothing lost.

**5. Five hard requirements are requests, not rules.** 🟡
Word limits and JSON output formats live as prose in five prompts — the model can (and does)
politely ignore them. **Proposal:** enforce with a PostToolUse hook and an output schema, then
delete the prose. A check that blocks beats a sentence that asks.

## Health board

| Axis | Status | Why |
|---|---|---|
| Preload cost (`/context`) | 🟡 | 8,900 tokens every session; ~6,800 is release-only |
| Skill listing budget (`/doctor`) | 🔴 | ~118% of budget — 2 skills silently truncated |
| Contradictions | 🔴 | commit-message rules give opposite orders |
| Broken references | 🔴 | 3 links/imports resolve to nothing |
| Duplicate & drifted rules | 🟡 | code-style in 3 diverged copies |
| Tool surface | 🟡 | 2 unused MCP servers, ~4,100 tokens for zero calls |
| Stale / unenforced | 🟡 | 5 hard requirements live as prose |

## What's healthy

- `.claude/rules/security.md` — enforced by the review hook, referenced by 3 skills, current.
  Leave it alone.
- The 9 project skills are compact and single-purpose; none exceeds a 2,000-token route.
- The permissions list is short and current — no zombie entries.

## Cleanup plan

Suggested order (platform wins and safe deletes first):

1. Apply `/doctor`'s three: disable `figma` + `sentry` for this project, trim the derivable
   CLAUDE.md content, and raise `skillListingBudgetFraction` or prune skills to end truncation.
2. Repoint the 2 moved references; delete the 1 dead import.
3. Resolve the commit-message contradiction; merge code-style ×3 → one home.
4. Split the release runbook out of `ship-release`'s head.
5. Convert the 5 prose requirements into a hook + schema.

| Metric | Before | After |
|---|---|---|
| Preload (`/context`) | 8,900 tok | 2,100 tok (−76%) |
| Skill listing vs budget | ~118% | ~90% (no truncation) |
| Unused MCP tool cost | ~4,100 tok | 0 (disabled) |
| Contradictions | 1 | 0 |
| Broken references | 3 | 0 |
| Diverged duplicates | 3 | 0 |

## Appendix — receipt

- **Platform ran:** `/context` (real per-category tokens) and `/doctor` (health pass) — both
  shared by the owner; cost figures above are real, not estimates.
- **Script scanned:** 2 CLAUDE.md, 14 rules, 34 skills (+ description sizes), 2 settings files
  (key names only), memory index, 4 hook registrations, MCP server names.
- **Cross-checks:** 3 broken references, 4 content-overlap pairs, 3 same-name diverged copies.
- **Skipped:** plugin internals (read-only marketplace copies).
- **Needs a human eye:** whether `docs/conventions.md` is one rule with `code-style.md` or a
  separate audience.

*No changes were made. Every arrow above is a proposal.*
