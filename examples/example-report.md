# Harness audit — example report

> Illustrative output for a mid-size project ("acme-app"). Numbers and paths are
> fictional but realistic. This is the **default one-command run**: it needs nothing from
> you, and costs are estimates from structure, marked "≈ / est." The optional sharpen step
> (real `/context` / `/doctor` numbers) is shown at the very end. Your report will be in the
> language you talk to Claude in.

## TL;DR

**Verdict: needs cleanup.** The setup commits an estimated **≈ 31k tokens** before the first
message, but the biggest problems aren't size — they're conflicts: two rules give opposite
instructions on commit messages, and a skill points at a runbook that was deleted in March.
Three moves fix most of it:

1. Resolve the commit-message contradiction (two rules, opposite orders) → the model stops
   guessing which one wins.
2. Fix or drop the 3 broken references → instructions stop pointing at deleted files.
3. Defer the release runbook out of the preload → ≈ −6.8k tokens (est.) on every non-release task.

## Findings by priority

**1. Two rules disagree on commit messages, and the model can't tell which wins.** 🔴
`.claude/rules/git.md` says *"commit messages in imperative mood, no body"*; the `ship-release`
skill's embedded checklist says *"every commit needs a body explaining why"*. Both load, they
contradict, and which one the model follows depends on reading order. **Proposal:** pick one
home (the rule), delete the directive from the skill, link to the rule. Contradictions are the
one failure no token count catches — nothing finds them but reading, so this needs no cost data.

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
The script's size map puts the CLAUDE.md + skill-head preload around ≈ 8.9k tokens (est.); ~6.8k
of it is the deployment runbook and rollback history reachable from `ship-release`'s head —
needed only at the verify step, if at all, yet on every session's route. The misplacement is
visible from structure alone; the exact weight is one `/context` away. **Proposal:** move it
behind a "read at verify" pointer. Preload drops ≈ 8.9k → ≈ 2.1k tokens with nothing lost.

**5. Five hard requirements are requests, not rules.** 🟡
Word limits and JSON output formats live as prose in five prompts — the model can (and does)
politely ignore them. **Proposal:** enforce with a PostToolUse hook and an output schema, then
delete the prose. A check that blocks beats a sentence that asks.

**6. The skill listing is near its budget.** 🟡
34 skills; the script totals ~15,900 chars of `description` text. The listing Claude reads to
pick a skill gets ~1% of the window (~2,000 tokens on a 200k model), and past it Claude Code
**silently truncates** the least-used descriptions — stripping the keywords that make a skill
discoverable. This is an estimate off char counts; `/doctor` reports the exact overrun and names
which skills are being cut. **Proposal:** trim or merge low-use skills before the platform
starts hiding them.

**7. Two MCP servers may be dead weight.** 🟡
`figma` and `sentry` are configured; their tool schemas load upfront every session. Whether they
went *unused this session* is a runtime fact only `/doctor` knows — flagged here as worth
checking, not asserted. **Proposal:** for projects that don't touch design or error triage,
disable them and reclaim the schema cost.

## Health board

Costs marked "est." are structural estimates; the rest are exact from the script.

| Axis | Status | Why |
|---|---|---|
| Preload weight | 🟡 | ≈ 8.9k tokens (est.) every session; ~6.8k is release-only |
| Skill-listing budget | 🟡 | ~15.9k desc chars — near the ~1% cap; `/doctor` confirms overrun |
| Contradictions | 🔴 | commit-message rules give opposite orders |
| Broken references | 🔴 | 3 links/imports resolve to nothing |
| Duplicate & drifted rules | 🟡 | code-style in 3 diverged copies |
| Tool surface | 🟡 | 2 MCP servers loaded upfront; usage unverified (see `/doctor`) |
| Stale / unenforced | 🟡 | 5 hard requirements live as prose |

## What's healthy

- `.claude/rules/security.md` — enforced by the review hook, referenced by 3 skills, current.
  Leave it alone.
- The 9 project skills are compact and single-purpose; none exceeds a 2,000-token route.
- The permissions list is short and current — no zombie entries.

## Cleanup plan

Suggested order (safe deletes and structural fixes first):

1. Repoint the 2 moved references; delete the 1 dead import.
2. Resolve the commit-message contradiction; merge code-style ×3 → one home.
3. Split the release runbook out of `ship-release`'s head.
4. Trim/merge low-use skills to bring the listing under its budget.
5. Convert the 5 prose requirements into a hook + schema.

| Metric | Before | After |
|---|---|---|
| Preload (est.) | ≈ 8.9k tok | ≈ 2.1k tok (−76%) |
| Skill-listing desc chars | ~15.9k | ~11k (under cap) |
| Contradictions | 1 | 0 |
| Broken references | 3 | 0 |
| Diverged duplicates | 3 | 0 |

## Appendix — receipt

- **Script scanned:** 2 CLAUDE.md, 14 rules, 34 skills (+ description sizes), 2 settings files
  (key names only), memory index, 4 hook registrations, MCP server names.
- **Cross-checks:** 3 broken references, 4 content-overlap pairs, 3 same-name diverged copies.
- **Costs:** structural estimates (word counts × ~1.3). Not run: `/context`, `/doctor`.
- **Skipped:** plugin internals (read-only marketplace copies).
- **Needs a human eye:** whether `docs/conventions.md` is one rule with `code-style.md` or a
  separate audience.

*No changes were made. Every arrow above is a proposal.*

---

## Sharpen (optional)

> Costs above are estimates. For exact per-category tokens and the platform's own health pass,
> run `/context` and `/doctor` in a fresh session (after `/clear`, before working) and paste
> them — the skill refines **only the cost section**, leaving the findings as they are. The
> report already stands on its own; this just swaps estimates for real numbers.
>
> Illustrative delta if you run them:
>
> - **`/context`** reports the preload at **28,400 real tokens** (the estimate was ≈ 31k) — the
>   "est." labels drop for those categories, and the release runbook measures **6,200 real
>   tokens**, confirming finding #4.
> - **`/doctor`** confirms the skill listing at **118% of budget** and names `data-export` +
>   `pdf-stamp` as the descriptions being truncated; flags `figma` + `sentry` as **unused this
>   session** (~4,100 tokens of schemas for zero calls); suggests trimming ~600 words of
>   repo-derivable content from CLAUDE.md.
>
> These fold in as free wins. The estimate got you the shape and the cleanup order; the platform
> got you the exact numbers — neither was a gate.
