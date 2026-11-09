#!/usr/bin/env bash
# Real frame rate of a shot preset, so the performance guard is a number and not an impression.
# The game runs in a window in real time (no fixed fps, vsync off); SessionLog measures the frames.
#   tools/bench.sh [preset=flare_fight] [seconds=9]   prints fps_avg / fps_low_1s / worst frame
#   tools/bench.sh --accept [preset]                  the last result becomes this machine's baseline
# With a baseline, a run prints the change against it and flags SLOWER below -10 %. Numbers are per
# machine (.captures/_bench, gitignored) and wobble by a few percent; the first 3 s are ignored (shader
# compilation). Close other heavy programs for a clean reading.
set -u
ACCEPT=0
if [ "${1:-}" = "--accept" ]; then
  ACCEPT=1
  shift
fi
PRESET="${1:-flare_fight}"
SECONDS_RUN="${2:-9}"
source "$(dirname "${BASH_SOURCE[0]}")/env.sh" || exit 3
cd "$PROJECT_ROOT" || exit 3
ensure_imported
DIR=".captures/_bench"
mkdir -p "$DIR"
if [ "$ACCEPT" -eq 1 ]; then
  cp -f "$DIR/$PRESET.last" "$DIR/$PRESET.base" 2>/dev/null && echo "baseline for $PRESET: $(cat "$DIR/$PRESET.base")" && exit 0
  echo "no result to accept for $PRESET (run tools/bench.sh $PRESET first)" >&2
  exit 1
fi

LOG=".captures/sessions/bench_$PRESET.jsonl"
rm -f "$LOG"
timeout 120 "$GODOT" --path "$PROJECT_ROOT" --resolution 1600x900 --disable-vsync \
  -- --shot="$PRESET" --bench="$SECONDS_RUN" >"$DIR/$PRESET.godot.log" 2>&1
END="$(grep '"type":"end"' "$LOG" 2>/dev/null | tail -n 1)"
if [ -z "$END" ]; then
  echo "BENCH FAIL: no result for $PRESET (see $DIR/$PRESET.godot.log)" >&2
  exit 1
fi
num() { echo "$END" | sed -nE "s/.*\"$1\":([0-9.]+).*/\1/p"; }
AVG="$(num fps_avg)"
LOW="$(num fps_low_1s)"
WORST="$(num worst_frame_ms)"
echo "fps_avg=$AVG fps_low_1s=$LOW worst_frame_ms=$WORST" >"$DIR/$PRESET.last"
LINE="BENCH $PRESET  fps_avg=$AVG  fps_low_1s=$LOW  worst_frame_ms=$WORST"
if [ -f "$DIR/$PRESET.base" ]; then
  BASE_AVG="$(sed -nE 's/.*fps_avg=([0-9.]+).*/\1/p' "$DIR/$PRESET.base")"
  LINE="$LINE  $(awk "BEGIN{d = ($AVG - $BASE_AVG) / $BASE_AVG * 100; printf \"(baseline %s, %+.0f%%%s)\", \"$BASE_AVG\", d, (d < -10 ? \" SLOWER\" : \"\")}")"
else
  LINE="$LINE  (no baseline yet: tools/bench.sh --accept $PRESET)"
fi
echo "$LINE"
grep -c '"type":"error"' "$LOG" | awk '$1 > 0 {print "script errors during the run: " $1}'
exit 0
