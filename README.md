# harness-audit

**Audit your Claude Code harness: find what quietly hurts it, get a cleanup plan.
Read-only.**

Your harness — CLAUDE.md files, rules, skills, commands, agents, hooks, memory, permissions,
MCP servers — grows one patch at a time. Every added rule fixed a real problem once. Nobody
sees the whole picture, and it all competes for the model's attention on every task. Then a
new model ships, inherits the pile, behaves differently — and you add another rule to fix
problems your instructions created.

## What makes this different from `/doctor`

Claude Code already ships two things this audit refuses to reinvent:

- **`/context`** — the real, per-category token cost of your window (system prompt, tools,
  MCP, agents, memory, the skill listing, messages). This is your actual budget.
- **`/doctor`** — the platform's own health pass: unused skills / MCP servers and their
  context cost, CLAUDE.md that can be trimmed, slow hooks, skill-listing budget overrun.

**harness-audit reads those first, then does the part they can't.** A word-count estimate of
token cost when `/context` reports the real number is exactly the kind of junk an audit should
flag — so this skill doesn't do it. Instead it goes past the platform to find:

- **broken references** — a rule pointing at a file that was renamed or deleted (the
  instruction still reads fine; the target is gone);
- **contradictions** — two rules that pull opposite ways, so the model silently picks one and
  you can't predict which;
- **drift** — the same rule living in several files that have quietly diverged;
- **prose that should be enforced** — hard limits and formats living as polite text the model
  can ignore, when they should be a hook, schema, or permission;
- **load-time bloat** — a whole procedure inlined into the preload, paid every session whether
  the task needs it or not.

Fat setups think richer and deliver worse. When "the new model got worse", the junk is often
yours. Treat the harness like a car: it needs scheduled maintenance.

### Why a harness is a budget

The context window is finite, and quality degrades as it fills — "context rot" is measured,
not folklore: models get worse as tokens accumulate, even on simple tasks
([Chroma, *Context Rot*](https://www.trychroma.com/research/context-rot)). Every instruction,
and every tool definition, competes for attention; curate them down to what earns its place,
and keep critical rules permanent rather than trusting them to survive compaction
([Anthropic, *Effective context engineering for AI agents*](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)).
The audit turns these principles into a map of *your* setup and a ranked cleanup.

## Requirements

- Claude Code
- bash ≥ 4.0 for the inventory script (macOS ships 3.2 — `brew install bash`)

## Install

Copy the skill into your project (or user) skills directory:

```bash
git clone https://github.com/slip-pro/harness-audit-skill
cp -r harness-audit-skill/skills/harness-audit <your-project>/.claude/skills/
cp -r harness-audit-skill/scripts <your-project>/.claude/skills/harness-audit/
```

Or keep the repo anywhere and reference the script by path — the skill works either way.

## Use

In a Claude Code session inside your project:

```
/harness-audit
```

or just ask: *"audit my harness"*. The skill runs in four phases:

1. **REAL NUMBERS** — it asks you to run `/context` and `/doctor` and share the output. These
   are interactive commands the model can't run for you; their numbers are the ground truth
   the whole audit stands on.
2. **MAP STRUCTURE** — `scripts/inventory.sh` (deterministic, bash-only, no dependencies)
   enumerates every surface and runs cross-checks the platform doesn't: broken references,
   content overlap, same-name duplicates.
3. **ANALYZE** — the model reads the actual files for what only reading finds: contradictions,
   drift, stale rules, prose-that-should-be-enforced, load-time misplacement, tool overlap.
4. **REPORT** — verdict-first: TL;DR, what `/doctor` already flags (cheapest wins), then the
   findings only this audit catches, a health board, what's healthy, and a cleanup plan with
   before/after numbers.

It changes **nothing**. Every proposal is a diff you decide to make (or not) after reading the
report. The report is written in whatever language you talk to Claude in.

### Non-standard layouts

Harness repos that keep skills outside `.claude/` (shared templates, monorepos):

```bash
HARNESS_AUDIT_EXTRA_SKILL_DIRS=/path/to/shared/skills bash scripts/inventory.sh /path/to/project
```

## The one number with a documented anchor

Most "how big is too big" questions have no universal answer — that's what `/context` is for,
on *your* window. The single threshold worth stating outright is the **skill-listing budget**
([Claude Code skills docs](https://code.claude.com/docs/en/skills)): the listing Claude reads
to pick a skill gets **~1% of the model's context window** (`skillListingBudgetFraction`;
per-skill cap 1,536 chars for `description` + `when_to_use`, via `skillListingMaxDescChars`).
Past the budget Claude Code **silently shortens descriptions**, starting with the least-used
skills — stripping exactly the keywords that make a skill discoverable. `/context` (v2.1.196+)
reports the listing's real size after the budget is applied; `/doctor` warns when it overran.

The inventory script prints raw word counts only (no token figure — it deliberately doesn't
guess what `/context` reports exactly). Treat the word counts as a **structure map and a rough
fallback**: to eyeball relative sizes when you haven't run `/context`, multiply mentally by
~1.3 for a ±30% token sense. When the real numbers are on the table, ignore the estimate.

## What it does NOT do

- **No automatic cleanup.** Read-only by design; apply-mode may come later.
- **No secret reading.** Settings are inventoried by key names and sizes only.
- **No re-measuring the platform.** Token cost comes from `/context` / `/doctor`, not a guess.
- **Claude Code only** (v1). Codex and other harnesses — maybe later.

## Limitations

- `/context` and `/doctor` are **interactive** — the model can't run them and read the output
  itself. The audit depends on you sharing their output; without it, cost figures fall back to
  the ±30% word-count estimate and the report says so.
- **Contradiction and drift detection is judgement, not a checksum.** The script surfaces
  overlap and same-name candidates deterministically; deciding whether two rules truly conflict
  (vs. serve different audiences) is the model reading them, and can miss or over-flag.
- Broken-reference scanning judges by source: a markdown link (`](path)`) or an `@`-import is
  an explicit file reference, so it's flagged by extension even without a `/` (an adjacent-file
  link like `](spec.md)` is caught); a backtick `` `path` `` is only judged when it looks
  path-like (has a `/`), because bare backtick mentions ("`spec.md`", "`harness-lint.sh`") are
  usually tool or command names — left to the semantic pass to avoid noise.
- `description:` counting reads the first frontmatter line only (multi-line descriptions are
  undercounted) and includes the key + newline (~14 bytes overhead per skill).
- Reference-chain tracing follows local markdown links to depth **2** by default
  (`HARNESS_AUDIT_CHAIN_DEPTH`); "reachable" is not "loaded", it's what a route CAN drag in.
- Plugin discovery covers `~/.claude/plugins`; marketplace layouts may vary.

## License

MIT.
