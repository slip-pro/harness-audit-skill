---
name: harness-audit
description: Audit your Claude Code harness — find what quietly hurts it. Reads the platform's own numbers (/context, /doctor) for real token cost, then goes past them: broken references, rules that contradict each other, the same rule drifting in two files, hard constraints living as ignorable prose, and load-time bloat. Use when the model "got worse", before switching models, or as periodic maintenance. Read-only — reports and proposes, never changes anything.
---

# harness-audit

Your harness — CLAUDE.md, rules, skills, commands, agents, hooks, memory, permissions,
MCP — grows one patch at a time. Every rule fixed a real problem once; nobody sees the
whole pile, and it competes for the model's attention on every task.

**This skill does NOT re-measure what the platform already measures.** Claude Code ships
`/context` (real per-category token cost of your window) and `/doctor` (its own health
pass: unused skills, CLAUDE.md bloat, slow hooks, skill-listing overrun). Guessing tokens
with a word count when those exist is exactly the kind of junk this audit is meant to find.
So the skill's job is the layer **on top**: read the platform's numbers, then find what the
platform can't — broken references, contradictions, drift, prose-that-should-be-enforced,
misplacement. Map first, judge second, change nothing.

**Invariants — read before doing anything:**
- **Read-only.** You never edit, move, or delete during the audit. Every change is a
  separate action the owner takes after reading the report.
- **No secret values.** Inventory settings and configs by key names and sizes only.
- **Real numbers over estimates.** Token cost comes from `/context` and `/doctor`, not from
  a word-count heuristic. Only fall back to word counts when the platform output is
  genuinely unavailable — and say so in the report.
- **Report in the language of the conversation.** The skill text is English; the report
  belongs to the user.

## Phase 1 — REAL NUMBERS (the platform already knows the cost)

Before mapping anything, get the ground truth the platform computes. As of this writing these
are **interactive-only** — an agent cannot run them and capture the output (the terminal
`claude doctor` only checks install health, not context cost). So **ask the owner to run each
and paste the result** (or read it off their screen if you share one):

1. **`/context`** — the real token cost of the current window, broken down by category:
   system prompt, system tools, MCP tools, custom agents, memory files, the skill listing,
   and conversation. This is the budget. Record each category's real number; note which
   ones dominate and which are surprisingly large for what they do.
2. **`/doctor`** — the platform's own findings: unused skills / MCP servers / plugins and
   their context cost, CLAUDE.md that can be trimmed, slow hooks, and — critically — whether
   the **skill listing overran its budget** (past ~1% of the window Claude Code silently
   truncates descriptions, starting with least-used skills, stripping the very keywords that
   make a skill discoverable). Capture every recommendation verbatim; these are free wins.
3. Optionally `/mcp` (tool count per server), `/hooks`, `/permissions`, `/memory` to confirm
   what's active.

If the owner can't or won't run these, say so plainly and fall back explicitly: use the
script's word counts as the budget proxy, multiply by ~1.3 for a ±30% token sense, and label
**every** cost figure in the report as an estimate (not a real token count). Don't stall
waiting for `/context`, and don't silently drop cost from the report — degrade to the estimate.

## Phase 2 — MAP STRUCTURE (what the numbers don't show)

Run the deterministic collector (requires bash ≥ 4):
`bash .claude/skills/harness-audit/scripts/inventory.sh <project-path>` — the path after the
standard install; if the repo is elsewhere, use its `scripts/inventory.sh`.
`HARNESS_AUDIT_EXTRA_SKILL_DIRS=/p1:/p2` covers non-standard skill layouts.

It enumerates every surface (CLAUDE.md, rules, skills + description sizes, commands, agents,
hooks, memory, MCP names) and runs three cross-checks a token count can't:
- **Broken references** — a rule/CLAUDE.md link pointing at a file that no longer exists.
  Silent rot: the instruction reads fine, the target is gone.
- **Content overlap** — differently-named files sharing several lines (drift candidates).
- **Same-name copies** — the fast exact-duplicate check, with a diverged/identical verdict.

Read the output as **structure and leads for Phase 3**, not as a verdict. Word counts here
are size, not cost — the cost lives in Phase 1. A surface that doesn't exist is noted and
skipped, never an error.

## Phase 3 — ANALYZE (read the content — this is the part a script can't do)

The platform gave you cost (Phase 1); the script gave you structure and mechanical leads
(Phase 2). Now **read the actual files** and find what neither can. Cite paths and numbers
for every finding. Six lenses:

1. **Contradictions.** Two rules that pull opposite ways — one says "always X", another
   "never X" for the same situation. The model silently picks one and you can't predict
   which. The most damaging finding and the hardest to see from counts alone: it needs
   reading. Follow the script's content-overlap and same-name leads first, then read across
   unrelated rules for conflicting directives.
2. **Drift.** The same rule living in several places with diverged wording (the script flags
   candidates — verify by reading each; same name with a genuinely different purpose is NOT
   drift). Each copy is a fork of the truth: one gets fixed, the others rot and quietly
   contradict it.
3. **Stale and dead.** Rules referencing tools, files, services, or workflows that no longer
   exist (start from the script's broken-references list, then judge the survivors:
   a rule about a process you stopped using costs attention and teaches the model wrong).
4. **Prose that should be enforced.** Hard requirements — word limits, output formats, safety
   invariants — living as polite text the model can (and does) ignore. Separate two grades:
   an ordinary requirement belongs in a hook / schema / permission rule; a **critical**
   instruction the model must never drop belongs somewhere **permanent** (a hook, a
   permission, an always-loaded line) — not in prose a mid-session compaction can summarize
   away. Flag critical rules that survive only as long as their raw text stays in the window.
5. **Load-time misplacement.** What loads every session (Phase 1 shows its real cost) but is
   only needed for one task type? A healthy surface preloads a *pointer* and opens the detail
   on demand — the way skills are meant to work. Flag the opposite: a whole procedure inlined
   into CLAUDE.md or a skill head, paid every session whether the task needs it. Use the
   script's per-skill reference chains to spot the heaviest routes.
6. **Tool & MCP surface.** From `/context` (real numbers) and `/doctor` (unused servers):
   more tools is not more capability — overlapping tools degrade selection and every schema
   spends context. Which servers are subscribed but unused here? Which overlap (two ways to
   do one job)? Which heavy schemas load upfront for a one-task-type need? The fix is a
   minimal, non-overlapping set: drop unused servers, prefer on-demand over upfront loading,
   and for MCP-heavy setups consider driving the server through code execution instead of
   exposing every tool.

## Phase 4 — REPORT (verdict first, platform wins first, then what only you found)

Write for a human who hasn't seen the audit. Every finding is a short story in plain
language — what's happening → why it hurts → what to do → what it saves. Keep the lens names
(contradiction / drift / stale / enforce / defer / trim-tools) internal; in the report they're
ordinary verbs in sentences, never headline codes. Structure, top to bottom:

1. **TL;DR (≤5 lines)** — one-phrase verdict (healthy / needs cleanup / cluttered), the single
   most telling number (a real token figure from `/context` when you have it), and the top 3
   actions with expected payoff.
2. **What `/doctor` already flags** — the platform's own recommendations, restated crisply, as
   the first and cheapest wins. Don't duplicate the platform; point to it and move on. If the
   owner didn't run it, say the audit is running blind on cost and recommend they do.
3. **What `/doctor` can't see — findings by priority** — the real payload of this skill.
   Critical first. Each: a short paragraph (what → why it hurts → proposal → expected saving);
   paths and numbers are the evidence, not the headline. Contradictions and broken references
   lead — they're the ones nothing else catches.
4. **Health board** — a compact traffic-light (green / yellow / red) over the axes that
   applied: real preload cost, skill-listing budget (from `/doctor`), duplicate & drifted
   rules, broken references, heaviest load routes, stale/unenforced rules, tool surface. One
   line of "why" per axis. Omit an axis you couldn't assess rather than guessing it green.
5. **What's healthy** — what to leave alone and why. Earns trust and stops the next audit from
   re-litigating settled calls.
6. **Cleanup plan** — proposed steps in execution order + a before → after table of the
   headline numbers if every proposal is accepted (real tokens where you have them).
7. **Appendix** — the receipt: what was scanned, what the platform reported, what was skipped
   and why, what needs a human eye. The owner decides; you propose.

Offer to re-run after cleanup to verify the before/after delta — and suggest scheduling it as
periodic maintenance (monthly, or before every model switch).
