#!/usr/bin/env bash
# harness-audit inventory — deterministic, read-only map of a Claude Code harness.
# Usage: bash scripts/inventory.sh [/path/to/project]   (default: current directory)
# No dependencies beyond coreutils + find + grep + awk. Writes nothing. Reads no secret values.
set -euo pipefail

TARGET="${1:-$PWD}"
TARGET="$(cd "$TARGET" && pwd)"
USER_CLAUDE="${CLAUDE_USER_DIR:-$HOME/.claude}"

words()  { [ -f "$1" ] && wc -w < "$1" || echo 0; }
lines()  { [ -f "$1" ] && wc -l < "$1" || echo 0; }

section() { printf '\n=== %s ===\n' "$1"; }

echo "harness-audit inventory"
echo "target : $TARGET"
echo "user   : $USER_CLAUDE"
echo "date   : (run timestamp intentionally omitted — output is diff-friendly)"

# ---------------------------------------------------------------- 1. CLAUDE.md
section "CLAUDE.md files (loaded at session start)"
PRELOAD_TOTAL=0
for f in "$TARGET/CLAUDE.md" "$TARGET/CLAUDE.local.md" "$USER_CLAUDE/CLAUDE.md"; do
  if [ -f "$f" ]; then
    w=$(words "$f"); PRELOAD_TOTAL=$((PRELOAD_TOTAL + w))
    imports=$(grep -cE '^@|[[:space:]]@[A-Za-z0-9_./-]+' "$f" 2>/dev/null || true)
    printf '%-60s %6s words  (@-imports: %s)\n' "${f/#$HOME/\~}" "$w" "${imports:-0}"
  fi
done
[ "$PRELOAD_TOTAL" -eq 0 ] && echo "(none found)"

# ------------------------------------------------------- 2. rules directories
section "Rules (project + user)"
RULES_TOTAL=0; RULES_COUNT=0
for d in "$TARGET/.claude/rules" "$TARGET/rules" "$USER_CLAUDE/rules"; do
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    w=$(words "$f"); RULES_TOTAL=$((RULES_TOTAL + w)); RULES_COUNT=$((RULES_COUNT + 1))
  done < <(find "$d" -name '*.md' -type f 2>/dev/null)
  n=$(find "$d" -name '*.md' -type f 2>/dev/null | wc -l)
  printf '%-60s %4s files\n' "${d/#$HOME/\~}" "$n"
done
echo "rules total: $RULES_COUNT files, $RULES_TOTAL words"

# ---------------------------------------------------------------- 3. skills
section "Skills (project + user + plugins)"
SKILL_DIRS=("$TARGET/.claude/skills" "$USER_CLAUDE/skills")
while IFS= read -r d; do SKILL_DIRS+=("$d"); done \
  < <(find "$USER_CLAUDE/plugins" -maxdepth 5 -type d -name skills 2>/dev/null)
# Non-standard layouts (e.g. a harness repo keeping skills outside .claude/):
# export HARNESS_AUDIT_EXTRA_SKILL_DIRS=/path/one:/path/two
IFS=':' read -ra EXTRA <<< "${HARNESS_AUDIT_EXTRA_SKILL_DIRS:-}"
for d in "${EXTRA[@]:-}"; do [ -n "$d" ] && [ -d "$d" ] && SKILL_DIRS+=("$d"); done
DESC_CHARS=0; SKILL_COUNT=0
for d in "${SKILL_DIRS[@]}"; do
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    SKILL_COUNT=$((SKILL_COUNT + 1))
    dc=$(grep -m1 '^description:' "$f" 2>/dev/null | wc -c)
    DESC_CHARS=$((DESC_CHARS + dc))
    printf '%-64s %5s lines %6s words  desc:%4s chars\n' \
      "$(dirname "${f/#$HOME/\~}" | awk -F/ '{print $(NF)}')" "$(lines "$f")" "$(words "$f")" "$dc"
  done < <(find "$d" -name 'SKILL.md' -type f 2>/dev/null | sort)
done
echo "skills total: $SKILL_COUNT skills, description budget used: $DESC_CHARS chars"

# ------------------------------------------------------ 4. commands + agents
section "Commands and agents"
for d in "$TARGET/.claude/commands" "$USER_CLAUDE/commands" "$TARGET/.claude/agents" "$USER_CLAUDE/agents"; do
  [ -d "$d" ] || continue
  n=$(find "$d" -name '*.md' -type f 2>/dev/null | wc -l)
  w=$(find "$d" -name '*.md' -type f -exec cat {} + 2>/dev/null | wc -w)
  printf '%-60s %4s files %8s words\n' "${d/#$HOME/\~}" "$n" "$w"
done

# ----------------------------------------------------------------- 5. hooks
section "Hooks (settings registration — names only, values never read)"
for f in "$TARGET/.claude/settings.json" "$TARGET/.claude/settings.local.json" "$USER_CLAUDE/settings.json"; do
  [ -f "$f" ] || continue
  n=$(grep -coE '"(PreToolUse|PostToolUse|Stop|SessionStart|SessionEnd|UserPromptSubmit|PreCompact|Notification)"' "$f" || true)
  printf '%-60s %4s hook event keys\n' "${f/#$HOME/\~}" "${n:-0}"
done

# ---------------------------------------------------------------- 6. memory
section "Memory (auto-memory)"
slug=$(printf '%s' "$TARGET" | tr '/' '-')
MEMDIR="$USER_CLAUDE/projects/$slug/memory"
if [ -d "$MEMDIR" ]; then
  n=$(find "$MEMDIR" -name '*.md' -type f | wc -l)
  printf '%-60s %4s files, MEMORY.md %s words\n' "${MEMDIR/#$HOME/\~}" "$n" "$(words "$MEMDIR/MEMORY.md")"
  PRELOAD_TOTAL=$((PRELOAD_TOTAL + $(words "$MEMDIR/MEMORY.md")))
else
  echo "(no memory dir for this project)"
fi

# ------------------------------------------------------------------- 7. MCP
section "MCP servers (names only)"
if [ -f "$TARGET/.mcp.json" ]; then
  grep -oE '"[A-Za-z0-9_-]+"[[:space:]]*:[[:space:]]*\{' "$TARGET/.mcp.json" | head -30 \
    | sed 's/[":{ ]//g' | sed 's/^/  - /' || true
else
  echo "(no .mcp.json)"
fi

# -------------------------------------------------- 8. duplicate candidates
section "Duplicate candidates (same basename, different locations)"
SCAN_DIRS=()
for d in "$TARGET/.claude" "$TARGET/rules" "$TARGET/shared" "$USER_CLAUDE/rules" "$USER_CLAUDE/skills" "$USER_CLAUDE/commands" "$USER_CLAUDE/agents"; do
  [ -d "$d" ] && SCAN_DIRS+=("$d")
done
DUP_FOUND=0
if [ "${#SCAN_DIRS[@]}" -gt 0 ]; then
  while IFS= read -r base; do
    mapfile -t hits < <(find "${SCAN_DIRS[@]}" -name "$base" -type f 2>/dev/null | grep -v node_modules | sort -u)
    [ "${#hits[@]}" -lt 2 ] && continue
    if [ "${#hits[@]}" -ge 4 ]; then
      # 4+ same-named files is almost always a structural convention (fixtures,
      # datasets, per-item templates), not a drifting rule copy. Note and move on.
      echo "  $base: ${#hits[@]} files — structural pattern, skipped (inspect manually if unexpected)"
      continue
    fi
    DUP_FOUND=$((DUP_FOUND + 1))
    echo "  $base:"
    for h in "${hits[@]}"; do
      printf '    %-70s %6s words\n' "${h/#$HOME/\~}" "$(words "$h")"
    done
    if cmp -s "${hits[0]}" "${hits[1]}"; then echo "    -> identical"; else echo "    -> DIVERGED"; fi
  done < <(find "${SCAN_DIRS[@]}" -name '*.md' -type f 2>/dev/null | grep -v node_modules \
           | awk -F/ '{print $NF}' | sort | uniq -d | grep -vE '^(SKILL|README|CLAUDE|MEMORY|index)\.md$')
fi
[ "$DUP_FOUND" -eq 0 ] && echo "(none)"

# ----------------------------------------------- 9. per-skill load chains
# "Reachable", not "loaded": the agent follows references selectively. A huge number
# here means a dense reference graph — the route CAN drag that much in. Depth default 2
# (the skill file + what it points at + one hop); override: HARNESS_AUDIT_CHAIN_DEPTH.
CHAIN_DEPTH="${HARNESS_AUDIT_CHAIN_DEPTH:-2}"
section "Per-skill reference chain (words reachable via local .md links, depth $CHAIN_DEPTH)"
chain_words() {  # $1 = SKILL.md path; BFS over local .md links, depth-capped
  local start="$1" depth=0 total=0
  local -A seen=(); local frontier=("$start") next=()
  while [ "$depth" -lt "$CHAIN_DEPTH" ] && [ "${#frontier[@]}" -gt 0 ]; do
    next=()
    for f in "${frontier[@]}"; do
      [ -n "${seen[$f]:-}" ] && continue
      seen["$f"]=1; total=$((total + $(words "$f")))
      while IFS= read -r ref; do
        for base in "$(dirname "$f")" "$TARGET"; do
          local cand; cand="$(realpath -m "$base/$ref" 2>/dev/null || true)"
          [ -f "$cand" ] && [ -z "${seen[$cand]:-}" ] && next+=("$cand") && break
        done
      done < <(grep -oE '\]\([^)#]+\.md\)|`[A-Za-z0-9_./-]+\.md`' "$f" 2>/dev/null \
               | sed -e 's/^](\(.*\))$/\1/' -e 's/^`\(.*\)`$/\1/' | sort -u)
    done
    frontier=("${next[@]:-}"); [ "${#frontier[@]}" -eq 1 ] && [ -z "${frontier[0]}" ] && frontier=()
    depth=$((depth + 1))
  done
  echo "$total ${#seen[@]}"
}
CHAIN_DIRS=("$TARGET/.claude/skills" "$USER_CLAUDE/skills")
for d in "${EXTRA[@]:-}"; do [ -n "$d" ] && [ -d "$d" ] && CHAIN_DIRS+=("$d"); done
for d in "${CHAIN_DIRS[@]}"; do
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    read -r cw cf < <(chain_words "$f")
    printf '%-64s reachable: %8s words across %3s files\n' \
      "$(dirname "${f/#$HOME/\~}" | awk -F/ '{print $(NF)}')" "$cw" "$cf"
  done < <(find "$d" -name 'SKILL.md' -type f 2>/dev/null | sort)
done

# ----------------------------------------------------------------- summary
section "Summary"
echo "session preload (CLAUDE.md files + MEMORY.md index): ~$PRELOAD_TOTAL words"
echo "rules: $RULES_COUNT files / $RULES_TOTAL words (loading model depends on your setup)"
echo "skills: $SKILL_COUNT, descriptions: $DESC_CHARS chars (discovery budget)"
echo "duplicate basenames flagged: $DUP_FOUND"
echo
echo "Numbers are a map, not a verdict. Interpretation happens in the harness-audit skill."
