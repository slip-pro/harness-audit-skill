---
name: harness-audit
description: Audit your Claude Code harness — find what quietly hurts it. One command, one report — the skill runs a deterministic inventory and reads your config, then flags broken references, rules that contradict each other, the same rule drifting across files, hard constraints living as ignorable prose, and load-time bloat. Token cost is estimated from structure and labeled as an estimate; you can optionally sharpen it with /context and /doctor. Use when the model "got worse", before switching models, or as periodic maintenance. Read-only — reports and proposes, never changes anything.
---

# harness-audit

Your harness — CLAUDE.md, rules, skills, commands, agents, hooks, memory, permissions,
MCP — grows one patch at a time. Every rule fixed a real problem once; nobody sees the
whole pile, and it competes for the model's attention on every task.

**One command → one report.** The skill runs end to end with no homework for the owner: a
deterministic script maps every surface and runs cross-checks, then you read the files for what
only reading finds. It produces a complete audit — findings *and* a cost picture — with zero
required interaction. The platform's `/context` and `/doctor` can *sharpen* the cost numbers if
the owner chooses to run them, but they are an optional refinement at the end, never a gate.

**It does not fake precision.** Token cost here is an estimate derived from structure (word
counts), and every cost figure says so. When exact numbers matter, the report points the owner
at `/context` (real per-category tokens) and `/doctor` (the platform's health pass) as a
one-step refinement — it never passes a guess off as the truth, and it invents no thresholds.
The skill's core value — broken references, contradictions, drift, misplacement, prose that
should be enforced — needs neither command; those come from the script and from reading.

**Invariants — read before doing anything:**
- **Read-only.** You never edit, move, or delete during the audit. Every change is a
  separate action the owner takes after reading the report.
- **No secret values.** Inventory settings and configs by key names and sizes only.
- **One command, no gate.** The audit completes from the script + file reading alone. Never
  block or wait for the owner to paste `/context` or `/doctor` — offer them only as optional
  sharpening at the very end.
- **Honest cost.** Estimates are labeled as estimates; exact numbers come only from the
  platform and only if the owner opts in. Invent no thresholds — the documented skill-listing
  budget (~1% of the window) is the only hard number you state.
- **Report in the language of the conversation.** The skill text is English; the report
  belongs to the user.

## Phase 1 — MAP STRUCTURE (deterministic, zero interaction)

Run the collector (requires bash ≥ 4):
`bash .claude/skills/harness-audit/scripts/inventory.sh <project-path>` — the path after the
standard install; if the repo is elsewhere, use its `scripts/inventory.sh`.
`HARNESS_AUDIT_EXTRA_SKILL_DIRS=/p1:/p2` covers non-standard skill layouts.

It enumerates every surface (CLAUDE.md, rules, skills + description sizes, commands, agents,
hooks, memory, MCP names) and runs three cross-checks a token count can't:
- **Broken references** — a rule/CLAUDE.md link pointing at a file that no longer exists.
  Silent rot: the instruction reads fine, the target is gone.
- **Content overlap** — differently-named files sharing several lines (drift candidates).
- **Same-name copies** — the fast exact-duplicate check, with a diverged/identical verdict.

The word counts are a **size map**, not tokens. They drive two things: the relative picture
(what dwarfs what — visible without any platform command) and the report's default cost
estimate (multiply by ~1.3 for a ±30% token sense, and always label it an estimate). The one
place to compare against a real threshold is the **skill-listing budget** (~1% of the window):
the script prints the total `description` chars — flag it when it's near or over ~1% of a
typical window, since past the cap Claude Code silently truncates the least-used descriptions.

Read the output as **structure and leads for Phase 2**, not as a verdict. A surface that
doesn't exist is noted and skipped, never an error.

## Phase 2 — ANALYZE (read the content — the part a script can't do)

The script gave you structure and mechanical leads. Now **read the actual files** and find what
it can't. Cite paths and numbers for every finding. Six lenses:

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
5. **Load-time misplacement.** What loads every session but is only needed for one task type?
   The script's size map and per-skill reference chains show the heaviest routes. A healthy
   surface preloads a *pointer* and opens the detail on demand — the way skills are meant to
   work. Flag the opposite: a whole procedure inlined into CLAUDE.md or a skill head, paid
   every session whether the task needs it. (If the owner later shares `/context`, its preload
   number confirms the real weight — but the misplacement is visible from structure alone.)
6. **Tool & MCP surface.** More tools is not more capability — overlapping tools degrade
   selection and every schema spends context. From the script's MCP names and the config: which
   servers overlap (two ways to do one job)? Which heavy schemas load upfront for a one-task
   need? The fix is a minimal, non-overlapping set: prefer on-demand over upfront loading, and
   for MCP-heavy setups consider driving the server through code execution instead of exposing
   every tool. (Which servers went *unused this session* is a runtime fact only `/doctor` knows
   — note it as an optional check, don't guess it.)

## Phase 3 — REPORT (verdict first — complete on its own)

Write for a human who hasn't seen the audit. Every finding is a short story in plain
language — what's happening → why it hurts → what to do → what it saves. Keep the lens names
(contradiction / drift / stale / enforce / defer / trim-tools) internal; in the report they're
ordinary verbs in sentences, never headline codes. Costs are the script's estimate, labeled as
such. Structure, top to bottom:

1. **TL;DR (≤5 lines)** — one-phrase verdict (healthy / needs cleanup / cluttered), the single
   most telling number (the estimated preload size, marked "≈ / estimate"), and the top 3
   actions with expected payoff.
2. **Findings by priority** — the payload. Critical first. Each: a short paragraph (what → why
   it hurts → proposal → expected saving); paths and numbers are the evidence, not the headline.
   Contradictions and broken references lead — they're the ones nothing else catches, and they
   need no cost data at all.
3. **Health board** — a compact traffic-light (green / yellow / red) over the axes that
   applied: preload weight (estimated), skill-listing budget (vs the ~1% anchor), duplicate &
   drifted rules, broken references, heaviest load routes, stale/unenforced rules, tool surface.
   One line of "why" per axis. Omit an axis you couldn't assess rather than guessing it green.
4. **What's healthy** — what to leave alone and why. Earns trust and stops the next audit from
   re-litigating settled calls.
5. **Cleanup plan** — proposed steps in execution order + a before → after table of the
   headline numbers if every proposal is accepted (estimated tokens, labeled).
6. **Appendix** — the receipt: what was scanned, what was skipped and why, what needs a human
   eye. The owner decides; you propose.
7. **Sharpen (optional, one line at the end)** — offer, don't push: *"Costs above are estimates
   from structure. For exact per-category tokens and the platform's own health pass — unused
   skills/servers this session, slow hooks, exact skill-listing overrun — run `/context` and
   `/doctor` in a fresh session and paste them; I'll refine only the cost section. This report
   stands on its own without it."*

Offer to re-run after cleanup to verify the delta — and suggest scheduling it as periodic
maintenance (monthly, or before every model switch).

## Phase 4 — SHARPEN (optional — only if the owner pastes the platform numbers)

Runs only if the owner takes up the offer. `/context` and `/doctor` are **interactive** — an
agent can't run them (the terminal `claude doctor` checks install health, not context cost), so
this depends entirely on the owner pasting output; never wait on it. When they do:

1. **`/context`** (run in a **fresh session** — after `/clear`, before working): every category
   *except* the conversation line is harness-fixed and identical for any session with this
   config. Replace the estimated preload/tool/MCP/agent/memory/skill-listing figures with these
   real numbers in the TL;DR, health board, and before/after table; drop the "≈ / estimate"
   labels for the categories now backed by real tokens. The conversation line is the owner's
   messages, not the harness — exclude it. (These are the *always-on* floor; on-demand skill
   bodies and subagent context don't appear here — keep those on the script's size map.)
2. **`/doctor`**: fold its findings in as their own short "the platform also flags" note —
   unused skills / MCP servers this session and their cost, CLAUDE.md it can trim, slow hooks,
   and whether the skill listing overran its budget. These are free wins; restate crisply and
   point to the platform, don't duplicate it.

Re-issue the affected sections only (not the whole report), clearly marked as the sharpened
pass, so the owner sees what changed once real numbers replaced the estimate.
