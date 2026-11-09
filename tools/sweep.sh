#!/usr/bin/env bash
# One look instead of several fix rounds: render a shot preset with different values of a tunable and
# put the results next to each other in ONE labelled image.
#   tools/sweep.sh <preset> <Class.property> <v1> <v2> [v3 ...]
#       e.g. tools/sweep.sh storm_peak MoodRig.fog_density 0.006 0.012 0.024
#   tools/sweep.sh <preset> -- "<A.x=1>" "<A.x=2 B.y=3>" ...
#       arbitrary variants: each one is a space-separated list of Class.property=value
# Nothing is edited: values go in through --set (src/harness/tunable_overrides.gd). Pick the best
# variant, then write it into the @export default (and SPEC where the value is listed).
# Env: SWEEP_FRAMES (default 60; the mid frame is shown), SHOT_JOBS (parallel captures, default 3).
set -u
PRESET="${1:?usage: tools/sweep.sh <preset> <Class.property> <v1> <v2> ...}"
shift
source "$(dirname "${BASH_SOURCE[0]}")/env.sh" || exit 3
cd "$PROJECT_ROOT" || exit 3
ensure_imported

VARIANTS=()
LABELS=()
if [ "${1:-}" = "--" ]; then
  shift
  for v in "$@"; do
    VARIANTS+=("$v")
    LABELS+=("$(echo "$v" | sed -E 's/[A-Za-z0-9_]+\.//g')")
  done
else
  PROP="${1:?missing Class.property}"
  shift
  for v in "$@"; do
    VARIANTS+=("$PROP=$v")
    LABELS+=("${PROP#*.}=$v")
  done
fi
if [ "${#VARIANTS[@]}" -lt 2 ]; then
  echo "sweep needs at least two variants" >&2
  exit 2
fi

DIR=".captures/_sweep"
rm -rf "$DIR" && mkdir -p "$DIR"
JOBS="${SHOT_JOBS:-3}"
running=0
for i in "${!VARIANTS[@]}"; do
  SETS=()
  for s in ${VARIANTS[$i]}; do
    SETS+=("--set=$s")
  done
  (
    CAPTURE_OUT="$DIR/$i" CAPTURE_PLAIN=1 bash tools/capture.sh "$PRESET" "${SWEEP_FRAMES:-60}" "${SETS[@]}" >"$DIR/$i.out" 2>&1
  ) &
  running=$((running + 1))
  if [ "$running" -ge "$JOBS" ]; then
    wait -n
    running=$((running - 1))
  fi
done
wait

ITEMS=()
for i in "${!VARIANTS[@]}"; do
  mapfile -t PNGS < <(ls "$DIR/$i"/f*.png 2>/dev/null | sort)
  if [ "${#PNGS[@]}" -eq 0 ]; then
    echo "variant ${LABELS[$i]}: capture failed: $(head -n 3 "$DIR/$i.out" | tr '\n' ' ' | cut -c1-200)"
    continue
  fi
  if ! grep -q '^TUNABLE ' "$DIR/$i.out"; then
    echo "variant ${LABELS[$i]}: NOT APPLIED (wrong class or property, or that node is never created in this preset)"
  fi
  ITEMS+=("${LABELS[$i]}=${PNGS[$(( ${#PNGS[@]} / 2 ))]}")
done
[ "${#ITEMS[@]}" -eq 0 ] && exit 1
if [ "${#ITEMS[@]}" -le 4 ]; then
  COLS=2; CELL=768x432
else
  COLS=3; CELL=512x288
fi
bash tools/img.sh sheet out="$DIR/sweep.png" cols="$COLS" cell="$CELL" "${ITEMS[@]}" | sed -E 's/^IMG_SHEET /sweep: /'
echo "variants (row by row): ${LABELS[*]}"
grep -h '^TUNABLE ' "$DIR/0.out" | awk '!seen[$0]++' | sed -E 's/^TUNABLE [^ ]+ /shipped default: /' | head -n 3
