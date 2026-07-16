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
3. **REPORT** — findings in five buckets (**keep / merge / defer-load / harden /
   remove**), before/after numbers, and a receipt of what was scanned.

It changes **nothing**. Every proposal is a diff you decide to make (or not) after
reading the report. The report is written in whatever language you talk to Claude in.

### Non-standard layouts

Harness repos that keep skills outside `.claude/` (shared templates, monorepos):

```bash
HARNESS_AUDIT_EXTRA_SKILL_DIRS=/path/to/shared/skills bash scripts/inventory.sh /path/to/project
```

## Reference thresholds

Raw numbers age well; verdicts don't. The script reports numbers — interpretation
guidelines as of **2026-07**:

| Metric | Comfortable | Worth a look | Trouble |
|---|---|---|---|
| Session preload (CLAUDE.md + memory index) | < 3k words | 3-8k words | > 8k words |
| Single skill load chain | < 5k words | 5-15k words | > 15k words |
| Skill descriptions total | < 8k chars | 8-16k chars | > 16k chars |
| Copies of one rule | 1 | 2 | 3+ |

These are maintenance heuristics, not laws. A 20k-word chain that loads exactly when
needed beats a 3k preload of stale rules.

## What it does NOT do

- **No automatic cleanup.** Read-only by design; apply-mode may come later.
- **No secret reading.** Settings are inventoried by key names and sizes only.
- **Claude Code only** (v1). Codex and other harnesses — maybe later.

## Limitations

- `description:` counting reads the first frontmatter line only; multi-line descriptions
  are undercounted.
- Load-chain tracing follows local markdown links up to depth 5; dynamically-loaded
  context (hooks output, MCP instructions) is enumerated but not weighed.
- Plugin discovery covers `~/.claude/plugins`; marketplace layouts may vary.

## License

MIT.
