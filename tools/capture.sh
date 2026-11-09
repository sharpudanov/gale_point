#!/usr/bin/env bash
# Render frames of the real game (NOT headless — headless renders nothing) with Movie Maker.
#   tools/capture.sh <preset> [frames=60]
# The game receives `-- --shot=<preset>` (main.gd -> BootArgs) to jump to a camera/storm state.
# Output: .captures/<preset>/fNNNNNNNN.png at 1600x900, 30 fps. Prints mid + last frame paths.
set -u
PRESET="${1:?usage: tools/capture.sh <preset> [frames]}"
FRAMES="${2:-60}"
source "$(dirname "${BASH_SOURCE[0]}")/env.sh" || exit 3
cd "$PROJECT_ROOT" || exit 3
ensure_imported

OUT=".captures/$PRESET"
rm -rf "$OUT" && mkdir -p "$OUT"
LOG="$OUT/godot.log"

timeout "${CAPTURE_TIMEOUT:-300}" "$GODOT" --path "$PROJECT_ROOT" \
  --write-movie "$OUT/f.png" --fixed-fps 30 --quit-after "$FRAMES" \
  --resolution 1600x900 --disable-vsync -- --shot="$PRESET" >"$LOG" 2>&1
CODE=$?
rm -f "$OUT"/*.wav   # Movie Maker's PNG writer also dumps audio; not needed

mapfile -t PNGS < <(ls "$OUT"/f*.png 2>/dev/null | sort)
if [ "${#PNGS[@]}" -eq 0 ]; then
  echo "CAPTURE FAIL: no frames written (exit $CODE). Errors:" >&2
  grep -E 'ERROR|error' "$LOG" | awk '!seen[$0]++' | head -n 15 >&2
  exit 1
fi
if grep -qE '^(SCRIPT|SHADER) ERROR' "$LOG"; then
  echo "CAPTURE WARN: errors during capture (see $LOG):" >&2
  grep -E -A1 '^(SCRIPT|SHADER) ERROR' "$LOG" | grep -v '^--$' | awk '!seen[$0]++' | head -n 10 >&2
fi
MID="${PNGS[$(( ${#PNGS[@]} / 2 ))]}"
LAST="${PNGS[$(( ${#PNGS[@]} - 1 ))]}"
echo "frames: ${#PNGS[@]} in $(cygpath -m "$PROJECT_ROOT/$OUT")"
echo "mid:  $(cygpath -m "$PROJECT_ROOT/$MID")"
echo "last: $(cygpath -m "$PROJECT_ROOT/$LAST")"
