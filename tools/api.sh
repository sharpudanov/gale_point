#!/usr/bin/env bash
# API ground truth, cheaper than a failed edit or reading a whole file. Works with the editor closed.
#   tools/api.sh <Class> [filter] [--inherited]
# - Engine class (FogVolume, Environment, Image, ...): properties with defaults, method signatures,
#   signals and enums straight from this Godot binary's ClassDB. A filter also searches inherited members.
# - Project class (any class_name in this repo, e.g. Drowned): its file plus an outline with line numbers
#   (exports, public vars, signals, public funcs), so you can Read just the part you need.
set -u
NAME="${1:?usage: tools/api.sh <Class> [filter] [--inherited]}"
source "$(dirname "${BASH_SOURCE[0]}")/env.sh" || exit 3
cd "$PROJECT_ROOT" || exit 3

FILE="$(grep -rlE "^class_name[[:space:]]+$NAME([[:space:]]|\$)" --include='*.gd' main.gd src tests tools 2>/dev/null | head -n 1)"
if [ -n "$FILE" ]; then
  FILTER="${2:-}"
  echo "PROJECT CLASS $NAME  $FILE  ($(wc -l < "$FILE") lines)"
  grep -nE '^(extends|signal|const|enum|@export|var [a-z]|func [a-z]|static func [a-z]|class [A-Z])' "$FILE" \
    | { if [ -n "$FILTER" ] && [ "$FILTER" != "--inherited" ]; then grep -i -- "$FILTER"; else cat; fi; } \
    | sed -E 's/[[:space:]]+##.*$//' | cut -c1-170
  exit 0
fi

ensure_imported
"$GODOT" --headless --path "$PROJECT_ROOT" --log-file "$PROJECT_ROOT/.captures/api.engine.log" \
  --script res://tools/api.gd -- "$@" 2>&1 | grep -vE '^(Godot Engine v|\[godot_ai|$)' | cut -c1-240
exit "${PIPESTATUS[0]}"
