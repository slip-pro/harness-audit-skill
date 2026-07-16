#!/usr/bin/env bash
# harness-audit inventory — deterministic, read-only map of a Claude Code harness.
# Usage: bash scripts/inventory.sh [/path/to/project]   (default: current directory)
#
# What this script IS: the mechanical layer. It finds things a script finds better than
# a human eye — broken references, content that overlaps across files, raw structure.
# What this script is NOT: the token budget. The platform already knows the real numbers
# (/context, /doctor); this script does not guess them. Word counts here are structure,
# not cost — see the NEXT block at the end. Writes nothing. Reads no secret values.
set -euo pipefail

# mapfile and associative arrays need bash 4+. macOS ships 3.2 by default.
if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
  echo "harness-audit requires bash >= 4. macOS ships bash 3.2; install via: brew install bash" >&2
  exit 1
fi

TARGET="${1:-$PWD}"
TARGET="$(cd "$TARGET" && pwd)"
USER_CLAUDE="${CLAUDE_USER_DIR:-$HOME/.claude}"

# tr strips BSD wc's leading spaces
words()  { { [ -f "$1" ] && wc -w < "$1" || echo 0; } | tr -d ' '; }
lines()  { { [ -f "$1" ] && wc -l < "$1" || echo 0; } | tr -d ' '; }

section() { printf '\n=== %s ===\n' "$1"; }
tilde()   { printf '%s' "${1/#$HOME/\~}"; }

echo "harness-audit inventory (structure map — not a token budget)"
echo "target : $TARGET"
echo "user   : $USER_CLAUDE"
echo "date   : (run timestamp intentionally omitted — output is diff-friendly)"

# ================================================================= STRUCTURE
# Sections 1-7 enumerate what exists and how big it is (in words — a size proxy,
# not a cost). Feed this to the skill's analysis; do not read a verdict from it.

# ---------------------------------------------------------------- 1. CLAUDE.md
section "CLAUDE.md files (loaded at session start — the preload)"
PRELOAD_TOTAL=0
for f in "$TARGET/CLAUDE.md" "$TARGET/CLAUDE.local.md" "$USER_CLAUDE/CLAUDE.md"; do
  if [ -f "$f" ]; then
    w=$(words "$f"); PRELOAD_TOTAL=$((PRELOAD_TOTAL + w))
    imports=$(grep -cE '^@|[[:space:]]@[A-Za-z0-9_./-]+' "$f" 2>/dev/null || true)
    printf '%-60s %6s words  (@-imports: %s)\n' "$(tilde "$f")" "$w" "${imports:-0}"
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
  n=$(find "$d" -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
  printf '%-60s %4s files\n' "$(tilde "$d")" "$n"
done
echo "rules total: $RULES_COUNT files, $RULES_TOTAL words"

# ---------------------------------------------------------------- 3. skills
section "Skills (project + user + plugins)"
SKILL_DIRS=("$TARGET/.claude/skills" "$USER_CLAUDE/skills")
while IFS= read -r d; do SKILL_DIRS+=("$d"); done \
  < <(find "$USER_CLAUDE/plugins" -maxdepth 5 -type d -name skills 2>/dev/null)
# Non-standard layouts (a harness repo keeping skills outside .claude/):
# export HARNESS_AUDIT_EXTRA_SKILL_DIRS=/path/one:/path/two
IFS=':' read -ra EXTRA <<< "${HARNESS_AUDIT_EXTRA_SKILL_DIRS:-}"
for d in ${EXTRA[@]+"${EXTRA[@]}"}; do [ -n "$d" ] && [ -d "$d" ] && SKILL_DIRS+=("$d"); done
DESC_CHARS=0; SKILL_COUNT=0
for d in "${SKILL_DIRS[@]}"; do
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    SKILL_COUNT=$((SKILL_COUNT + 1))
    dc=$(grep -m1 '^description:' "$f" 2>/dev/null | wc -c)
    DESC_CHARS=$((DESC_CHARS + dc))
    printf '%-64s %5s lines %6s words  desc:%4s chars\n' \
      "$(dirname "$(tilde "$f")" | awk -F/ '{print $(NF)}')" "$(lines "$f")" "$(words "$f")" "$dc"
  done < <(find "$d" -name 'SKILL.md' -type f 2>/dev/null | sort)
done
echo "skills total: $SKILL_COUNT skills, description budget used: $DESC_CHARS chars"
echo "(the platform caps this at ~1% of the context window and truncates past it — verify with /context)"

# ------------------------------------------------------ 4. commands + agents
section "Commands and agents"
for d in "$TARGET/.claude/commands" "$USER_CLAUDE/commands" "$TARGET/.claude/agents" "$USER_CLAUDE/agents"; do
  [ -d "$d" ] || continue
  n=$(find "$d" -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
  w=$(find "$d" -name '*.md' -type f -exec cat {} + 2>/dev/null | wc -w)
  printf '%-60s %4s files %8s words\n' "$(tilde "$d")" "$n" "$w"
done

# ----------------------------------------------------------------- 5. hooks
section "Hooks (settings registration — event keys only, values never read)"
for f in "$TARGET/.claude/settings.json" "$TARGET/.claude/settings.local.json" "$USER_CLAUDE/settings.json"; do
  [ -f "$f" ] || continue
  n=$(grep -coE '"(PreToolUse|PostToolUse|Stop|SessionStart|SessionEnd|UserPromptSubmit|PreCompact|Notification)"' "$f" || true)
  printf '%-60s %4s hook event keys\n' "$(tilde "$f")" "${n:-0}"
done
echo "(a hook is an ENFORCED check — the skill separates these from prose that only asks)"

# ---------------------------------------------------------------- 6. memory
section "Memory (auto-memory)"
slug=$(printf '%s' "$TARGET" | tr '/' '-')
MEMDIR="$USER_CLAUDE/projects/$slug/memory"
if [ -d "$MEMDIR" ]; then
  n=$(find "$MEMDIR" -name '*.md' -type f | wc -l | tr -d ' ')
  printf '%-60s %4s files, MEMORY.md %s words\n' "$(tilde "$MEMDIR")" "$n" "$(words "$MEMDIR/MEMORY.md")"
  PRELOAD_TOTAL=$((PRELOAD_TOTAL + $(words "$MEMDIR/MEMORY.md")))
else
  echo "(no memory dir for this project)"
fi

# ------------------------------------------------------------------- 7. MCP
section "MCP servers (config names only — real tool cost comes from /context, not here)"
if [ -f "$TARGET/.mcp.json" ]; then
  # Loose parse (no jq dependency): server names are keys under mcpServers, minus the
  # common nested config keys. Approximate: a server literally named "url" is undercounted.
  mapfile -t MCP_SERVERS < <(grep -oE '"[A-Za-z0-9_.-]+"[[:space:]]*:[[:space:]]*\{' "$TARGET/.mcp.json" \
    | sed 's/[":{ ]//g' \
    | grep -viE '^(mcpServers|command|args|env|type|url|headers|disabled|timeout|cwd)$' || true)
  for s in ${MCP_SERVERS[@]+"${MCP_SERVERS[@]}"}; do echo "  - $s"; done
  echo "mcp servers configured here: ${#MCP_SERVERS[@]}  (each adds an instruction block + tool schemas; weigh the real cost with /context)"
else
  echo "(no project .mcp.json — MCP may still be configured at user/global level; check /mcp and /context)"
fi

# ============================================================ CROSS-CHECKS
# Sections 8-10 are the reason this script exists: findings a word count can't
# produce. The skill's semantic pass builds on these, it does not replace them.

# ------------------------------------------ 8. broken references (dead links)
# A rule that points at a file which no longer exists is silent rot: the instruction
# reads fine, the target is gone. We scan every harness prose file for outgoing
# file references and report the ones that resolve nowhere. Conservative on purpose —
# only flags path-like refs with a known extension or an @-import, to keep noise low.
section "Broken references (a rule points at a file that isn't there)"
REF_SCAN=()
for f in "$TARGET/CLAUDE.md" "$TARGET/CLAUDE.local.md" "$USER_CLAUDE/CLAUDE.md"; do
  [ -f "$f" ] && REF_SCAN+=("$f")
done
for d in "$TARGET/.claude/rules" "$TARGET/rules" "$USER_CLAUDE/rules" \
         "$TARGET/.claude/skills" "$USER_CLAUDE/skills" \
         "$TARGET/.claude/commands" "$USER_CLAUDE/commands" \
         "$TARGET/.claude/agents" "$USER_CLAUDE/agents"; do
  [ -d "$d" ] || continue
  while IFS= read -r f; do REF_SCAN+=("$f"); done \
    < <(find "$d" -name '*.md' -type f 2>/dev/null)
done

resolves() {  # $1 = referenced path, $2 = dir of the referencing file. 0 if it exists somewhere.
  local ref="$1" base="$2" cand
  ref="${ref%%#*}"                      # drop #anchor
  ref="${ref/#\~/$HOME}"                # expand ~
  case "$ref" in /*) [ -e "$ref" ] && return 0 || return 1 ;; esac
  for root in "$base" "$TARGET" "$TARGET/.claude" "$USER_CLAUDE"; do
    cand="$(realpath -m "$root/$ref" 2>/dev/null || true)"
    [ -n "$cand" ] && [ -e "$cand" ] && return 0
  done
  return 1
}

DEAD_FOUND=0
for f in ${REF_SCAN[@]+"${REF_SCAN[@]}"}; do
  fdir="$(dirname "$f")"
  # Collect candidate references: markdown links, backtick paths, @-imports.
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    # Filters: skip URLs, placeholders, globs, anchors-only.
    case "$ref" in
      *://*|\#*|"") continue ;;
      *"<"*|*">"*|*"*"*|*"..."*|*"{"*|*"}"*|*" "*) continue ;;
    esac
    # Only judge a real broken LINK: a path (has a "/") ending in a known extension, or an
    # @-import. A bare filename mention ("spec.md", "harness-lint.sh") is usually conceptual
    # or a tool name — that's the semantic pass's job, not a deterministic dead-link.
    case "$ref" in
      @*) refpath="${ref#@}" ;;
      */*.md|*/*.sh|*/*.json|*/*.py|*/*.ts|*/*.js|*/*.mjs|*/*.cjs|*/*.yaml|*/*.yml|*/*.toml|*/*.ps1|*/*.txt) refpath="$ref" ;;
      *) continue ;;
    esac
    if ! resolves "$refpath" "$fdir"; then
      DEAD_FOUND=$((DEAD_FOUND + 1))
      printf '  %s\n      -> %s  (not found — moved, renamed, deleted, or a tool name?)\n' \
        "$(tilde "$f")" "$refpath"
    fi
  done < <(
    {
      grep -oE '\]\([^)]+\)'                 "$f" 2>/dev/null | sed -e 's/^](//' -e 's/)$//'
      grep -oE '`[^`]+`'                      "$f" 2>/dev/null | sed 's/`//g'
      grep -oE '(^|[[:space:]])@[A-Za-z0-9_./~-]+' "$f" 2>/dev/null | tr -d ' \t'
    } | sort -u
  )
done
[ "$DEAD_FOUND" -eq 0 ] && echo "(none — every path-like reference resolves)"

# ---------------------------------------- 9. content overlap (drift candidates)
# v1 only caught same-basename copies. Real drift hides in DIFFERENTLY named files
# that share content. We hash each meaningful line (normalized, length-filtered) and
# report file pairs that share several — a signal of copy-paste that has since drifted.
# Literal-line overlap only; paraphrased drift is the skill's semantic pass, by design.
section "Content overlap (differently-named files sharing text — drift candidates)"
OVERLAP_MIN="${HARNESS_AUDIT_OVERLAP_MIN:-6}"   # min shared meaningful lines to report
OVERLAP_SCAN=()
for d in "$TARGET/.claude" "$TARGET/rules" "$TARGET/shared" "$USER_CLAUDE/rules" "$USER_CLAUDE/skills"; do
  [ -d "$d" ] || continue
  while IFS= read -r f; do OVERLAP_SCAN+=("$f"); done \
    < <(find "$d" -name '*.md' -type f 2>/dev/null | grep -v node_modules)
done
OVERLAP_REPORTED=0
if [ "${#OVERLAP_SCAN[@]}" -ge 2 ]; then
  # awk: normalize lines, map line->files, then count shared meaningful lines per file pair.
  # Ignore lines shared by >4 files (structural boilerplate, not drift).
  overlap_out=$(
    for f in "${OVERLAP_SCAN[@]}"; do
      awk -v FN="$f" '
        { line=$0
          gsub(/^[ \t>#*+-]+/, "", line)        # strip leading markdown markers
          gsub(/[ \t]+$/, "", line)             # trailing ws
          gsub(/[ \t]+/, " ", line)             # collapse internal ws
          if (length(line) >= 30) print FN "\t" tolower(line)
        }' "$f"
    done | awk -F'\t' '
      { lst[$2]=lst[$2] "\x01" $1 }        # per normalized line, accumulate its files
      END {
        for (k in lst) {
          n=split(substr(lst[k],2), arr, "\x01")
          # unique files
          delete uniq; m=0
          for (i=1;i<=n;i++) if (!(arr[i] in uniq)) { uniq[arr[i]]=1; ord[++m]=arr[i] }
          if (m<2 || m>4) continue
          for (i=1;i<m;i++) for (j=i+1;j<=m;j++) {
            pair=ord[i] "\t" ord[j]; pc[pair]++
          }
        }
        for (p in pc) print pc[p] "\t" p
      }' | sort -rn
  )
  while IFS=$'\t' read -r sc a b; do
    [ -z "${sc:-}" ] && continue
    [ "$sc" -lt "$OVERLAP_MIN" ] && continue
    OVERLAP_REPORTED=$((OVERLAP_REPORTED + 1))
    printf '  %s shared lines:\n    %s\n    %s\n' "$sc" "$(tilde "$a")" "$(tilde "$b")"
  done <<< "$overlap_out"
fi
[ "$OVERLAP_REPORTED" -eq 0 ] && echo "(none above threshold ${OVERLAP_MIN} shared lines)"

# --------------------------------------- 10. same-basename copies (fast dup check)
section "Same-name files in different locations (fast duplicate check)"
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
      echo "  $base: ${#hits[@]} files — structural pattern, skipped (inspect manually if unexpected)"
      continue
    fi
    DUP_FOUND=$((DUP_FOUND + 1))
    echo "  $base:"
    for h in "${hits[@]}"; do
      printf '    %-70s %6s words\n' "$(tilde "$h")" "$(words "$h")"
    done
    if cmp -s "${hits[0]}" "${hits[1]}"; then echo "    -> identical"; else echo "    -> DIVERGED (read both — same name may mean different purpose)"; fi
  done < <(find "${SCAN_DIRS[@]}" -name '*.md' -type f 2>/dev/null | grep -v node_modules \
           | awk -F/ '{print $NF}' | sort | uniq -d | grep -vE '^(SKILL|README|CLAUDE|MEMORY|index)\.md$')
fi
[ "$DUP_FOUND" -eq 0 ] && echo "(none)"

# ----------------------------------------------- 11. per-skill load chains
# "Reachable", not "loaded": the agent follows references selectively. A large number
# means a dense reference graph — the route CAN drag that much in. Depth default 2.
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
for d in ${EXTRA[@]+"${EXTRA[@]}"}; do [ -n "$d" ] && [ -d "$d" ] && CHAIN_DIRS+=("$d"); done
for d in "${CHAIN_DIRS[@]}"; do
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    read -r cw cf < <(chain_words "$f")
    printf '%-64s reachable: %8s words across %3s files\n' \
      "$(dirname "$(tilde "$f")" | awk -F/ '{print $(NF)}')" "$cw" "$cf"
  done < <(find "$d" -name 'SKILL.md' -type f 2>/dev/null | sort)
done

# ----------------------------------------------------------------- summary
section "Summary (structure — NOT a budget)"
echo "session preload (CLAUDE.md files + MEMORY.md index): $PRELOAD_TOTAL words"
echo "rules: $RULES_COUNT files / $RULES_TOTAL words"
echo "skills: $SKILL_COUNT, descriptions: $DESC_CHARS chars"
echo "broken references: $DEAD_FOUND    content-overlap pairs: $OVERLAP_REPORTED    same-name copies: $DUP_FOUND"
echo
echo "-------------------------------------------------------------------------------"
echo "NEXT — get the REAL numbers from the platform (this script does not guess them):"
echo "  /context   — real per-category token cost of your window (preload, tools, MCP,"
echo "               agents, memory, skill listing, messages). Paste it into the session."
echo "  /doctor    — the platform's own health pass: unused skills/servers vs their cost,"
echo "               CLAUDE.md bloat, slow hooks, skill-listing budget overrun."
echo "Word counts above are a size map for the analysis, not tokens. The harness-audit"
echo "skill reads /context + /doctor for cost, and this output for structure & cross-checks."
