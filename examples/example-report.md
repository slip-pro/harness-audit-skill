# Harness audit — example report

> Illustrative output for a mid-size project ("acme-app"). Numbers and paths are
> fictional but realistic; your report will be in the language you talk to Claude in.

## TL;DR

**Verdict: needs cleanup.** The setup works, but one release route drags **38,400 words**
of instructions before any work starts, and 3 rules exist in diverged copies — the model
regularly reads competing versions of the truth. Three moves fix most of it:

1. Merge the three copies of the code-style rule into one → no more competing truths.
2. Split the release runbook out of the `ship-release` skill head → route drops 38k → 9k words.
3. Turn five prose requirements (word limits, JSON formats) into enforced checks → they stop being optional.

## Health board

| Axis | Status | Why |
|---|---|---|
| Session preload | 🟡 | 4,120 words load every session — livable, but a third is only needed for releases |
| Duplicate rules | 🔴 | 3 of 4 same-name copies have quietly diverged |
| Skill catalog | 🟡 | 11,300 chars of descriptions — the model reads all of it to pick one skill |
| Heaviest routes | 🔴 | `ship-release` reaches 38,400 words across 21 files |
| Stale / unenforced | 🟡 | 1 rule guards a deleted service; 5 hard requirements live as polite prose |

## Findings, by priority

**1. The code-style rule lives in three places, and all three disagree.** 🔴
`.claude/rules/` says one thing (410 words), `docs/conventions/` another (380), and the
copy inside the `ship-release` skill a third (505) — and only that last one mentions the
linter that actually runs. Whichever version the model reads first wins; fixes land in
one copy and rot in the others. **Proposal:** keep `.claude/rules/code-style.md` as the
single home, replace the other two with links. Saves ~800 words of contradictions and
every future three-way fix.

**2. Starting a release means reading a small book.** 🔴
The `ship-release` skill links the full deployment runbook and the rollback history right
from its head, so any release task starts by dragging in 38,400 words — needed only at
the verify step, if at all. **Proposal:** move the runbook behind a "read at the verify
phase" pointer. The route shrinks 38k → ~9k words (−76%) with nothing lost.

**3. Five hard requirements are requests, not rules.** 🟡
Word limits and JSON output formats live as prose in five prompts — the model can (and
sometimes does) politely ignore them. **Proposal:** enforce them with a PostToolUse hook
and an output schema, then delete the prose. A check that blocks beats a sentence that asks.

**4. A rule guards a service that no longer exists.** 🟡
`legacy-api.md` describes precautions for an API deleted in March. No code references it,
no hook reads it — it only costs attention. **Proposal:** delete it; nothing breaks.

**5. An 8-month-old memory note still shapes every answer.** 🟡
"Always show steps" was saved once, long ago, and still applies to everything.
**Proposal:** confirm with the owner it's still wanted; if not, remove it from memory.

## What's healthy

- `.claude/rules/security.md` — enforced by the review hook, referenced by 3 skills,
  updated last month. Leave it alone.
- The 9 project skills are compact and single-purpose; none exceeds a 5k-word route.
- The permissions list is short and current — no zombie entries.

## Cleanup plan

Suggested order (cheap and safe first):

1. Delete `legacy-api.md`; confirm & clear the stale memory note.
2. Merge `code-style.md` ×3 and `naming.md` ×2 → one home each, links elsewhere.
3. Split the release runbook out of `ship-release`'s head.
4. Convert the 5 prose requirements into a hook + schema.

| Metric | Before | After |
|---|---|---|
| Session preload | 4,120 w | 2,780 w (−33%) |
| Heaviest route | 38,400 w | 9,200 w (−76%) |
| Diverged duplicates | 3 | 0 |
| Prose-only hard requirements | 5 | 0 |

## Appendix — inventory & receipt

| Metric | Value |
|---|---|
| Session preload (CLAUDE.md ×2 + memory index) | 4,120 words |
| Rules | 14 files / 6,890 words |
| Skills | 23 (project 9, user 6, plugins 8) |
| Skill descriptions total | 11,300 chars |
| Heaviest skill reference chain (depth 2) | `ship-release`: 38,400 words / 21 files |
| Duplicate basenames flagged | 4 (3 diverged, 1 same-purpose) |

Scanned: 2 CLAUDE.md, 14 rules, 23 skills (+descriptions), 2 settings files (key names
only), memory index, 4 hook registrations. Skipped: MCP instruction blocks (2 servers —
enumerate manually), plugin internals (read-only marketplace copies). Needs a human eye:
whether the two `naming.md` copies are truly one rule or two audiences.

*No changes were made. Every arrow above is a proposal.*
