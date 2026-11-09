#!/usr/bin/env bash
# Headless gameplay simulation. All args are forwarded to tests/sim_bot.gd (see its header).
#   tools/sim.sh --plan=res://tests/plans/smoke.json --frames=600 --expect="physics_frames>=600"
# Full log: .captures/sim/last.log. Exit code: sim_bot's (0 pass, 1 expect, 2 errors, 3 setup),
# or 4 if Godot crashed / produced no SIM_RESULT line.
set -u
source "$(dirname "${BASH_SOURCE[0]}")/env.sh" || exit 3
cd "$PROJECT_ROOT" || exit 3
ensure_imported
mkdir -p .captures/sim
LOG=".captures/sim/last.log"

timeout "${SIM_TIMEOUT:-300}" "$GODOT" --headless --fixed-fps 60 --path "$PROJECT_ROOT" \
  --script res://tests/sim_bot.gd -- "$@" >"$LOG" 2>&1
CODE=$?

# Show only the signal; the raw engine log stays in $LOG.
if grep -q '^SIM_RESULT' "$LOG"; then
  grep -E '^(SIM_|TELEMETRY|DELTA|EXPECT|    \| )' "$LOG" | head -n "${SIM_MAX_LINES:-80}"
else
  # Crash / hang / parse failure before the bot could report: show unique engine errors + crash dump.
  grep -E '^(SIM_|TELEMETRY|SCRIPT ERROR|ERROR|SHADER ERROR|CrashHandler|\[[0-9]+\] )|^\s+at: .*res://' "$LOG"     | awk '!seen[$0]++' | head -n "${SIM_MAX_LINES:-40}"
  echo "SIM_RESULT FAIL code=$CODE reason=crash/timeout/no result (full log: $LOG)"
  [ "$CODE" -eq 0 ] && CODE=4
fi
exit $CODE
