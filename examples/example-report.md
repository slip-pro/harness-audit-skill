# Harness audit — example report

> Illustrative output for a mid-size project ("acme-app"). Numbers and paths are
> fictional but realistic; your report will be in the language you talk to Claude in.

## TL;DR

**Verdict: needs cleanup.** The setup works, but one release route drags **38,400 words**
(~50k tokens) of instructions before any work starts, 3 rules exist in diverged copies —
the model reads competing versions of the truth — and six MCP servers load ~40 tools every
session, two of them redundant. Three moves fix most of it:

1. Merge the three copies of the code-style rule into one → no more competing truths.
2. Defer the release runbook *and* the 12 release-only MCP tools → the heaviest route drops 38k → 9k words and the tool surface shrinks on every non-release task.
3. Turn five prose requirements (word limits, JSON formats) into enforced checks → they stop being optional.

## Health board

| Axis | Status | Why |
|---|---|---|
| Session preload | 🟡 | 4,120 words load every session — livable, but a third is only needed for releases |
| Duplicate rules | 🔴 | 3 of 4 same-name copies have quietly diverged |
| Skill catalog | 🟡 | 11,300 chars of descriptions — the model reads all of it to pick one skill |
| Heaviest routes | 🔴 | `ship-release` reaches 38,400 words across 21 files |
| Stale / unenforced | 🟡 | 1 rule guards a deleted service; 5 hard requirements live as polite prose |
| Tool surface | 🔴 | 6 MCP servers, ~40 tools every session; 2 overlap (both fetch URLs), 12 are release-only |

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

**3. Every task carries the whole toolbox, including the release-only half.** 🔴
Six MCP servers register ~40 tools, and all of them load every session. Two overlap — the
`web` and `scrape` servers both fetch URLs, so the model chooses between near-duplicates on
every call — and the deploy server's 12 tools are touched only at release. **Proposal:**
drop one of the overlapping fetchers and move the deploy server behind on-demand loading
(or drive it through code execution), so ~40 tools stop competing for attention on ordinary
tasks. Fewer, non-overlapping tools measurably sharpen selection.

**4. Five hard requirements are requests, not rules.** 🟡
Word limits and JSON output formats live as prose in five prompts — the model can (and
sometimes does) politely ignore them. **Proposal:** enforce them with a PostToolUse hook
and an output schema, then delete the prose. A check that blocks beats a sentence that asks.

**5. A rule guards a service that no longer exists.** 🟡
`legacy-api.md` describes precautions for an API deleted in March. No code references it,
no hook reads it — it only costs attention. **Proposal:** delete it; nothing breaks.

**6. An 8-month-old memory note still shapes every answer.** 🟡
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
5. Drop one overlapping fetch server; defer the deploy server's 12 tools behind on-demand loading.

| Metric | Before | After |
|---|---|---|
| Session preload | 4,120 w | 2,780 w (−33%) |
| Heaviest route | 38,400 w | 9,200 w (−76%) |
| Diverged duplicates | 3 | 0 |
| Prose-only hard requirements | 5 | 0 |
| Tools loaded every session | ~40 | ~28 (release tools deferred) |

## Appendix — inventory & receipt

| Metric | Value |
|---|---|
| Session preload (CLAUDE.md ×2 + memory index) | 4,120 words (~5,350 tokens) |
| Rules | 14 files / 6,890 words |
| Skills | 23 (project 9, user 6, plugins 8) |
| Skill descriptions total | 11,300 chars |
| Heaviest skill reference chain (depth 2) | `ship-release`: 38,400 words / 21 files |
| Duplicate basenames flagged | 4 (3 diverged, 1 same-purpose) |
| MCP servers / live tools | 6 servers / ~40 tools (2 overlapping, 12 release-only) |

Scanned: 2 CLAUDE.md, 14 rules, 23 skills (+descriptions), 2 settings files (key names
only), memory index, 4 hook registrations, and the live tool surface (6 MCP servers /
~40 tools). Skipped: plugin internals (read-only marketplace copies). Needs a human eye:
whether the two `naming.md` copies are truly one rule or two audiences.

*No changes were made. Every arrow above is a proposal.*
