#!/usr/bin/env bash
# Stop hook: no turn ends on a silently red suite.
# If game or test files changed since the last fully green `tools/sim.sh --all`, the suite runs here
# (about 30 s, in parallel). Green -> the turn ends as usual. Red -> exit 2 with the failing scenarios, so
# Claude either fixes them or tells the user plainly that the suite is red and why. Each distinct red state
# is reported once, and never twice in a row (stop_hook_active), so it cannot loop.
# Nothing changed since the last green run -> two `find` calls and out.
set -u
INPUT="$(cat 2>/dev/null || true)"
case "$INPUT" in
  *'"stop_hook_active":true'*|*'"stop_hook_active": true'*) exit 0 ;;
esac
source "$(dirname "${BASH_SOURCE[0]}")/env.sh" 2>/dev/null || exit 0   # no Godot -> never block
cd "$PROJECT_ROOT" || exit 0
GREEN=".captures/sim/.suite_green"
RED=".captures/sim/.suite_red"

newer_than() {   # prints one watched file that is newer than stamp $1 (nothing if none)
  find main.gd project.godot src shaders tests -type f \
    \( -name '*.gd' -o -name '*.gdshader' -o -name '*.json' -o -name 'suite.txt' -o -name 'project.godot' \) \
    -newer "$1" 2>/dev/null | head -n 1
}

if [ -f "$GREEN" ] && [ -z "$(newer_than "$GREEN")" ]; then
  exit 0
fi
if [ -f "$RED" ] && [ -z "$(newer_than "$RED")" ]; then
  exit 0   # this exact red state was already reported
fi

OUT="$(bash tools/sim.sh --all 2>&1)"
if [ $? -eq 0 ]; then
  rm -f "$RED"
  exit 0
fi
mkdir -p .captures/sim && touch "$RED"
{
  echo "tools/sim.sh --all is RED after this turn's changes:"
  echo "$OUT" | grep -vE 'SIM_RESULT PASS' | head -n 12 | cut -c1-300
  echo "Fix the regression, or update the expectation if the rule changed on purpose (tests follow rules)."
  echo "If you stop anyway, tell the user plainly that the suite is red and why."
} >&2
exit 2
