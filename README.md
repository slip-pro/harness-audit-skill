# harness-audit

**Audit your Claude Code harness: map every instruction the model carries, find the
junk, get a cleanup plan. Read-only.**

Your harness — CLAUDE.md files, rules, skills, commands, agents, hooks, memory,
permissions, MCP servers — grows one patch at a time. Every added rule fixed a real
problem once. Nobody sees the whole picture, and no screen shows it. Then a new model
ships, inherits the pile, behaves differently — and you add another rule to fix problems
your instructions created.

Typical findings this audit surfaces:

- one writing route silently dragging **thousands of words** of instructions before the
  actual work starts;
- the same rule living in **several copies** that drifted apart — the model gets
  competing versions of the truth;
- skill descriptions exceeding the **discovery budget**, so the model can't even read
  the full catalog to route correctly;
- hard requirements (word limits, JSON formats) living as **polite prose** instead of
  enforced checks.

Fat setups think richer and deliver worse. When "the new model got worse", the junk is
often yours. Treat the harness like a car: it needs scheduled maintenance.

## Why a harness is a budget

The context window is finite, and quality degrades as it fills — "context rot" is
measured, not folklore: models get worse as tokens accumulate, even on simple tasks
([Chroma, *Context Rot*](https://www.trychroma.com/research/context-rot)). Two
consequences drive this audit:

- **Every instruction competes for attention.** Curate the system prompt, rules, and
  memory down to what earns its place, and keep critical rules permanent rather than
  trusting them to survive compaction ([Anthropic, *Effective context engineering for AI
  agents*](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)).
- **More tools is not more capability.** Overlapping, always-loaded tool sets degrade
  selection; a minimal, non-overlapping set — loaded on demand, not all upfront — beats a
  kitchen sink. Tool definitions are a real, often large, context cost.

The audit turns these principles into a map of *your* setup and a ranked cleanup.

## Requirements

- Claude Code
- bash ≥ 4.0 for the inventory script (macOS ships 3.2 — `brew install bash`)

## Install

Copy the skill into your project (or user) skills directory:

```bash
git clone https://github.com/<owner>/harness-audit-skill
cp -r harness-audit-skill/skills/harness-audit <your-project>/.claude/skills/
cp -r harness-audit-skill/scripts <your-project>/.claude/skills/harness-audit/
```

Or keep the repo anywhere and reference the script by path — the skill works either way.

## Use

In a Claude Code session inside your project:

```
/harness-audit
```

or just ask: *"audit my harness"*. The skill will:

1. **MAP** — run `scripts/inventory.sh` (deterministic, bash-only, no dependencies) and
   enumerate every surface: where it lives, when it loads, how big it is.
2. **ANALYZE** — duplicates & drift, load-time misplacement, budget pressure,
   stale/unenforced rules.
3. **REPORT** — a verdict-first writeup: TL;DR, a health board, findings by priority,
   what's healthy, and a cleanup plan with before/after numbers and a receipt of what was
   scanned.

It changes **nothing**. Every proposal is a diff you decide to make (or not) after
reading the report. The report is written in whatever language you talk to Claude in.

### Non-standard layouts

Harness repos that keep skills outside `.claude/` (shared templates, monorepos):

```bash
HARNESS_AUDIT_EXTRA_SKILL_DIRS=/path/to/shared/skills bash scripts/inventory.sh /path/to/project
```

## Reference thresholds

Raw numbers age well; verdicts don't. The script reports word counts (plus a rough
`~words×1.3` token estimate — a ±30% scale heuristic, not a billing count) —
interpretation guidelines as of **2026-07**:

| Metric | Comfortable | Worth a look | Trouble |
|---|---|---|---|
| Session preload (CLAUDE.md + memory index) | < 3k words | 3-8k words | > 8k words |
| Single skill load chain | < 5k words | 5-15k words | > 15k words |
| Skill descriptions total | fits the listing budget¹ | ~1-2× budget | > 2× budget |
| Copies of one rule | 1 | 2 | 3+ |
| Tool surface (live tools) | minimal, non-overlapping | some overlap / a few unused servers | many servers, heavy schemas all loaded upfront |

¹ The skill-descriptions row has a documented anchor ([Claude Code skills docs](https://code.claude.com/docs/en/skills)):
the skill listing gets **1% of the model's context window** (configurable via
`skillListingBudgetFraction`; per-skill cap 1,536 chars for `description` +
`when_to_use`, via `skillListingMaxDescChars`). On a 200k-token model that's ~2,000
tokens — very roughly 8k English chars. Past the budget Claude Code silently shortens
descriptions starting with the least-used skills, stripping exactly the keywords that
make a skill discoverable. Run `/doctor` to see your listing's actual cost.

The other rows are maintenance heuristics, not laws. A 20k-word chain that loads exactly
when needed beats a 3k preload of stale rules. The Tool-surface row stays qualitative on
purpose — tool counts are model- and runtime-dependent, so overlap and upfront-vs-deferred
loading matter more than any fixed number.

## What it does NOT do

- **No automatic cleanup.** Read-only by design; apply-mode may come later.
- **No secret reading.** Settings are inventoried by key names and sizes only.
- **Claude Code only** (v1). Codex and other harnesses — maybe later.

## Limitations

- `description:` counting reads the first frontmatter line only (multi-line descriptions
  are undercounted) and includes the `description:` key and newline (~14 bytes overhead
  per skill).
- Reference-chain tracing follows local markdown links up to depth **2** by default
  (skill + direct references + one hop; override via `HARNESS_AUDIT_CHAIN_DEPTH`).
  "Reachable" is not "loaded" — it measures how much a route CAN drag in. Dynamic
  context (hooks output, MCP instructions) is enumerated but not weighed.
- Plugin discovery covers `~/.claude/plugins`; marketplace layouts may vary.
- Token figures are a `~words×1.3` heuristic (±30%) — a way to read word counts in the
  unit the budget is spent in, not an exact tokenizer count. Run `/doctor` for real costs.
- The **tool surface** is inventoried by the skill from the *live* session (the tools the
  running model actually carries), not by the script — the script only sees MCP server
  names in `.mcp.json`. Tool schemas and per-server instruction blocks load at runtime and
  are weighed in the analysis, not the collector.

## License

MIT.
