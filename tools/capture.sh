#!/usr/bin/env bash
# Render frames of the real game in a window (NOT headless: headless renders nothing).
#   tools/capture.sh <preset> [frames=60] [extra game args, e.g. --set=MoodRig.fog_density=0.02]
# The game receives `-- --shot=<preset>` (main.gd -> BootArgs) to jump to a camera/storm state and runs
# at a fixed 30 fps, so frame N is always the same instant. FrameSnapper (src/harness) saves only the
# frames that get looked at, as .captures/<preset>/fNNNNNNNN.png at 1600x900. Prints:
#   mid / last   full-resolution frames (mid = frame frames/2, i.e. t = 1.0 s for the default 60)
#   strip        6 frames spread over the capture in ONE labelled image: motion, timing, flashes
#   pair         previous capture | this one | difference x4 for this preset, plus change metrics
#                (mad = mean change in %, changed = % of pixels that clearly moved; noise is < 0.3 / 1)
# Env: CAPTURE_OUT=<dir> writes elsewhere (sweeps, shots); CAPTURE_PLAIN=1 = first/mid/last only, no
# strip / pair.
set -u
PRESET="${1:?usage: tools/capture.sh <preset> [frames] [extra game args]}"
shift
FRAMES=60
if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
  FRAMES="$1"
  shift
fi
[ "$FRAMES" -lt 2 ] && FRAMES=2
EXTRA=("$@")
source "$(dirname "${BASH_SOURCE[0]}")/env.sh" || exit 3
cd "$PROJECT_ROOT" || exit 3
ensure_imported

if [ "$PRESET" != "test" ] && ! grep -qE "^[[:space:]]*\"$PRESET\":" src/core/shot_presets.gd; then
  NAMES="$(sed -nE 's/^[[:space:]]*"([a-z0-9_]+)":.*/\1/p' src/core/shot_presets.gd | paste -sd' ' -)"
  echo "CAPTURE FAIL: unknown preset '$PRESET'. Presets: $NAMES" >&2
  exit 2
fi
OUT="${CAPTURE_OUT:-.captures/$PRESET}"
PREV=".captures/_prev/$PRESET.png"
if [ -z "${CAPTURE_OUT:-}" ]; then
  # Keep the mid frame of the capture this run replaces, so a fix round can be compared with it.
  mapfile -t OLD < <(ls "$OUT"/f*.png 2>/dev/null | sort)
  if [ "${#OLD[@]}" -gt 0 ]; then
    mkdir -p .captures/_prev && cp -f "${OLD[$(( ${#OLD[@]} / 2 ))]}" "$PREV"
  fi
fi
rm -rf "$OUT" && mkdir -p "$OUT"
LOG="$OUT/godot.log"

MID_N=$(( FRAMES / 2 ))
LAST_N=$(( FRAMES - 1 ))
STRIP_N=()
LIST="0,$MID_N,$LAST_N"
if [ -z "${CAPTURE_PLAIN:-}" ]; then
  for k in 0 1 2 3 4 5; do
    STRIP_N+=( $(( k * LAST_N / 5 )) )
  done
  LIST="$LIST,$(IFS=,; echo "${STRIP_N[*]}")"
fi
frame() { printf '%s/f%08d.png' "$OUT" "$1"; }
abs() { cygpath -m "$PROJECT_ROOT/$1" 2>/dev/null || printf '%s\n' "$PROJECT_ROOT/$1"; }

timeout "${CAPTURE_TIMEOUT:-300}" "$GODOT" --path "$PROJECT_ROOT" --fixed-fps 30 \
  --quit-after "$(( FRAMES + 240 ))" --resolution 1600x900 --disable-vsync \
  -- --shot="$PRESET" --snap="$OUT" --snap_frames="$LIST" "${EXTRA[@]}" >"$LOG" 2>&1
CODE=$?

if [ ! -f "$(frame "$MID_N")" ] || [ ! -f "$(frame "$LAST_N")" ]; then
  echo "CAPTURE FAIL: frames not written (exit $CODE). Errors:" >&2
  grep -E 'ERROR|error' "$LOG" | awk '!seen[$0]++' | head -n 15 >&2
  exit 1
fi
if grep -qE '^(SCRIPT|SHADER) ERROR' "$LOG"; then
  echo "CAPTURE WARN: errors during capture (see $LOG):" >&2
  grep -E -A1 '^(SCRIPT|SHADER) ERROR' "$LOG" | grep -v '^--$' | awk '!seen[$0]++' | head -n 10 >&2
fi
grep -E '^TUNABLE ' "$LOG" | awk '!seen[$0]++' | head -n 12
echo "frames: $FRAMES at 30 fps in $(abs "$OUT")"
echo "mid:  $(abs "$(frame "$MID_N")")"
echo "last: $(abs "$(frame "$LAST_N")")"
[ -n "${CAPTURE_PLAIN:-}" ] && exit 0

ITEMS=()
for n in "${STRIP_N[@]}"; do
  ITEMS+=("t=$(awk "BEGIN{printf \"%.2f\", $n / 30}")s=$(frame "$n")")
done
if bash tools/img.sh sheet out="$OUT/strip.png" cols=3 cell=512x288 "${ITEMS[@]}" >/dev/null; then
  echo "strip: $(abs "$OUT/strip.png")  (6 frames across $(awk "BEGIN{printf \"%.1f\", $FRAMES / 30}") s, in one image)"
fi
if [ -z "${CAPTURE_OUT:-}" ] && [ -f "$PREV" ]; then
  DIFF="$(bash tools/img.sh diff "$PREV" "$(frame "$MID_N")" out="$OUT/pair.png" | grep -oE 'mad=[0-9.]+ changed=[0-9.]+')"
  echo "pair:  $(abs "$OUT/pair.png")  (previous capture | this one | difference x4; $DIFF)"
fi
exit 0
