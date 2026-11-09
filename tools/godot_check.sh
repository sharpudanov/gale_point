#!/usr/bin/env bash
# PostToolUse hook (Write|Edit|MultiEdit). Reads the hook JSON on stdin.
# For .gd/.gdshader/.tres/.tscn edits: headless Godot import (when needed) + parse/load check.
# Real errors -> concise "res://file:line: message" lines on stderr, exit 2. Otherwise exit 0.
# Manual use: tools/godot_check.sh --file path/to/file.gd
set -u
source "$(dirname "${BASH_SOURCE[0]}")/env.sh" || exit 0   # no Godot -> never block edits
cd "$PROJECT_ROOT" || exit 0

if [ "${1:-}" = "--file" ]; then
  FILE="${2:-}"
else
  INPUT="$(cat)"
  if command -v node >/dev/null 2>&1; then
    FILE="$(printf '%s' "$INPUT" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);process.stdout.write((j.tool_input&&(j.tool_input.file_path||j.tool_input.notebook_path))||"")}catch(e){}})')"
  else
    FILE="$(printf '%s' "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//; s/\\/\//g')"
  fi
fi
[ -z "$FILE" ] && exit 0

case "$FILE" in
  *.gd|*.gdshader|*.tres|*.tscn) ;;
  *) exit 0 ;;
esac

# Map to res:// (skip files outside the project or inside .godot/).
ABS="$(cygpath -u "$FILE" 2>/dev/null || printf '%s' "$FILE")"
case "$ABS" in /*) ;; *) ABS="$PROJECT_ROOT/$ABS" ;; esac
ROOT_LC="$(printf '%s' "$PROJECT_ROOT" | tr '[:upper:]' '[:lower:]')"
ABS_LC="$(printf '%s' "$ABS" | tr '[:upper:]' '[:lower:]')"
case "$ABS_LC" in "$ROOT_LC"/*) ;; *) exit 0 ;; esac
REL="${ABS:${#PROJECT_ROOT}+1}"
case "$REL" in .godot/*|.captures/*) exit 0 ;; esac
RES="res://$REL"

# Re-import only when the class_name table may be stale (import costs ~2-3 s).
CACHE=".godot/global_script_class_cache.cfg"
if [ ! -f "$CACHE" ]; then
  ensure_imported force
elif [ "${FILE##*.}" = "gd" ] && [ -f "$ABS" ]; then
  CN="$(grep -m1 -oE '^class_name[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' "$ABS" | awk '{print $2}')"
  if [ -n "$CN" ] && ! grep -A6 "\"class\": &\"$CN\"" "$CACHE" | grep -q "\"path\": \"$RES\""; then
    ensure_imported force
  elif [ -z "$CN" ] && grep -q "\"path\": \"$RES\"" "$CACHE"; then
    ensure_imported force   # class_name was removed
  fi
fi

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
timeout 120 "$GODOT" --headless --path "$PROJECT_ROOT" --script res://tools/check.gd -- "$RES" >"$LOG" 2>&1
CODE=$?

ERRORS="$(awk '
  function flush(loc) {
    if (msg == "") return
    line = (loc != "" ? loc ": " : "") msg
    if (!(line in seen)) { seen[line] = 1; out[++n] = line }
    msg = ""
  }
  /^CHECK_SHADER / { flush(""); shader = $2; next }
  /^CHECK_FAIL / { flush(""); fails[++nf] = substr($0, 12); next }
  /^(SCRIPT ERROR|SHADER ERROR|USER ERROR|ERROR): / {
    flush("")
    m = $0
    sub(/^(SCRIPT ERROR|SHADER ERROR|USER ERROR|ERROR): /, "", m)
    if (m ~ /^Failed to load script/ || m ~ /^Shader compilation failed/) next   # redundant
    msg = m; next
  }
  /^[[:space:]]+at: / && msg != "" {
    loc = ""
    if (match($0, /\(res:\/\/[^)]*\)/)) loc = substr($0, RSTART + 1, RLENGTH - 2)
    else if (match($0, /\(:[0-9]+\)/) && shader != "") loc = shader substr($0, RSTART + 1, RLENGTH - 2)
    flush(loc); next
  }
  END {
    flush("")
    for (i = 1; i <= n; i++) print out[i]
    for (i = 1; i <= nf; i++) {          # only if no detailed error already names that file
      split(fails[i], p, ":"); f = p[1] ":" p[2]; named = 0
      for (j = 1; j <= n; j++) if (index(out[j], f) == 1) named = 1
      if (!named) print fails[i]
    }
  }' "$LOG" | head -n 20)"

if [ -n "$ERRORS" ]; then
  echo "Godot check failed after editing $RES:" >&2
  echo "$ERRORS" >&2
  exit 2
fi
if [ "$CODE" -ne 0 ]; then
  echo "Godot check exited with code $CODE after editing $RES (no parsable error; run: tools/godot_check.sh --file $REL)" >&2
  exit 2
fi
exit 0
