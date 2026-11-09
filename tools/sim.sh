#!/usr/bin/env bash
# Headless gameplay simulation. All args are forwarded to tests/sim_bot.gd (see its header).
#   tools/sim.sh --plan=res://tests/plans/smoke.json --frames=600 --expect="physics_frames>=600"
# Full log: .captures/sim/last.log. Exit code: sim_bot's (0 pass, 1 expect, 2 errors, 3 setup),
# or 4 if Godot crashed / produced no SIM_RESULT line.
#   tools/sim.sh --all [name...]   runs every scenario in tests/suite.txt (or only the named ones),
#                                  one PASS/FAIL line each; exit 0 only if all pass.
# --all runs scenarios in parallel (each is its own headless Godot, so results do not depend on it):
# SIM_JOBS=n sets how many at once (default: half the CPU threads, at most 8; SIM_JOBS=1 = one by one).
# Per-scenario output and engine log: .captures/sim/suite/<name>.out / <name>.log.
set -u
source "$(dirname "${BASH_SOURCE[0]}")/env.sh" || exit 3
cd "$PROJECT_ROOT" || exit 3
ensure_imported

if [ "${1:-}" = "--all" ]; then
  shift
  SUITE="tests/suite.txt"
  SELF="$PROJECT_ROOT/tools/sim.sh"
  only=" $* "
  JOBS="${SIM_JOBS:-$(( $(nproc 2>/dev/null || echo 4) / 2 ))}"
  [ "$JOBS" -gt 8 ] && [ -z "${SIM_JOBS:-}" ] && JOBS=8
  [ "$JOBS" -lt 1 ] && JOBS=1
  OUT_DIR=".captures/sim/suite"
  rm -rf "$OUT_DIR" && mkdir -p "$OUT_DIR"
  names=()
  running=0
  while read -r name rest; do
    case "$name" in ''|'#'*) continue ;; esac
    if [ "$only" != "  " ] && [[ "$only" != *" $name "* ]]; then continue; fi
    read -ra args <<< "$rest"
    names+=("$name")
    (
      SIM_LOG="$OUT_DIR/$name.log" SIM_TIMEOUT="${SIM_TIMEOUT:-600}" SIM_MAX_LINES=400 \
        bash "$SELF" --plan="res://tests/plans/$name.json" "${args[@]}" </dev/null >"$OUT_DIR/$name.out" 2>&1
      echo $? >"$OUT_DIR/$name.code"
    ) &
    running=$((running + 1))
    if [ "$running" -ge "$JOBS" ]; then
      wait -n
      running=$((running - 1))
    fi
  done < "$SUITE"
  wait
  fails=0
  for name in "${names[@]}"; do
    code="$(cat "$OUT_DIR/$name.code" 2>/dev/null || echo 4)"
    [ "$code" -ne 0 ] && fails=$((fails + 1))
    result=$(grep -E '^SIM_RESULT' "$OUT_DIR/$name.out" | tail -1)
    detail=$(grep -E 'EXPECT FAIL|SIM_ERROR' "$OUT_DIR/$name.out" | head -3 | tr '\n' ' ')
    printf '%-18s %s %s\n' "$name" "${result:-SIM_RESULT FAIL code=$code (no result line)}" "$detail"
  done
  total="${#names[@]}"
  echo "SUITE $((total - fails))/$total passed"
  # A full green run stamps the tree; tools/gate.sh (Stop hook) reruns the suite only if files are newer.
  if [ "$fails" -eq 0 ] && [ "$only" = "  " ]; then
    touch .captures/sim/.suite_green
  fi
  [ "$fails" -eq 0 ]
  exit $?
fi
mkdir -p .captures/sim
LOG="${SIM_LOG:-.captures/sim/last.log}"

# --log-file keeps the engine's own rotating log out of the shared user-data folder, so parallel runs
# never fight over it.
timeout "${SIM_TIMEOUT:-300}" "$GODOT" --headless --fixed-fps 60 --path "$PROJECT_ROOT" \
  --log-file "$PROJECT_ROOT/${LOG%.log}.engine.log" \
  --script res://tests/sim_bot.gd -- "$@" >"$LOG" 2>&1
CODE=$?

# Show only the signal; the raw engine log stays in $LOG.
if grep -q '^SIM_RESULT' "$LOG"; then
  grep -E '^(SIM_|TELEMETRY|DELTA|EXPECT|    \| )' "$LOG" | head -n "${SIM_MAX_LINES:-80}"
else
  # Crash / hang / parse failure before the bot could report: show unique engine errors + crash dump.
  grep -E '^(SIM_|TELEMETRY|SCRIPT ERROR|ERROR|SHADER ERROR|CrashHandler|\[[0-9]+\] )|^\s+at: .*res://' "$LOG"     | awk '!seen[$0]++' | head -n "${SIM_MAX_LINES:-40}"
  echo "SIM_RESULT FAIL code=4 reason=crash/timeout/no result (engine exit $CODE, full log: $LOG)"
  CODE=4
fi
exit $CODE
