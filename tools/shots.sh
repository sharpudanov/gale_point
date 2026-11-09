#!/usr/bin/env bash
# Visual regression suite: every shot preset is rendered and compared with its accepted baseline, so a
# script finds unintended visual changes and Claude only looks at what changed.
#   tools/shots.sh [preset...]            capture (all presets by default), compare, build ONE contact sheet
#   tools/shots.sh --accept [preset...]   after review: the frames of the last run become the baseline
# Status per preset:
#   SAME     within render noise of the baseline          CHANGED  look at its pair image (baseline | now | diff)
#   NEW      no baseline yet                              BLANK    black frame
#   ERROR    script / shader error, or no frames written
# Exit 1 only on ERROR / BLANK. CHANGED is a flag for eyes, not a failure: an intended change is accepted
# with --accept once it has been looked at.
# Baselines are per machine (.captures/_base, gitignored) because GPUs render slightly differently.
# A preset is CHANGED when mad > SHOT_TOL (0.5 %) or changed > SHOT_CTOL (2 % of pixels); two renders of
# the same code differ by at most mad 0.25 / changed 0.8 on this project.
# Env: SHOT_JOBS (parallel captures, default 4), SHOT_TOL, SHOT_CTOL.
set -u
source "$(dirname "${BASH_SOURCE[0]}")/env.sh" || exit 3
cd "$PROJECT_ROOT" || exit 3
ensure_imported

ACCEPT=0
if [ "${1:-}" = "--accept" ]; then
  ACCEPT=1
  shift
fi
mapfile -t PRESETS < <(sed -nE 's/^[[:space:]]*"([a-z0-9_]+)":.*/\1/p' src/core/shot_presets.gd)
if [ "$#" -gt 0 ]; then
  PRESETS=("$@")
fi
BASE=".captures/_base"
OUT=".captures/_shots"

if [ "$ACCEPT" -eq 1 ]; then
  mkdir -p "$BASE"
  n=0
  for p in "${PRESETS[@]}"; do
    mapfile -t PNGS < <(ls "$OUT/$p"/f*.png 2>/dev/null | sort)
    [ "${#PNGS[@]}" -eq 0 ] && continue
    cp -f "${PNGS[$(( ${#PNGS[@]} / 2 ))]}" "$BASE/$p.png" && n=$((n + 1))
  done
  echo "accepted $n baseline(s) in $BASE"
  exit 0
fi

rm -rf "$OUT" && mkdir -p "$OUT"
JOBS="${SHOT_JOBS:-4}"
running=0
for p in "${PRESETS[@]}"; do
  (
    CAPTURE_OUT="$OUT/$p" CAPTURE_PLAIN=1 bash tools/capture.sh "$p" 60 >"$OUT/$p.out" 2>&1
    echo $? >"$OUT/$p.code"
  ) &
  running=$((running + 1))
  if [ "$running" -ge "$JOBS" ]; then
    wait -n
    running=$((running - 1))
  fi
done
wait

bad=0
for p in "${PRESETS[@]}"; do
  code="$(cat "$OUT/$p.code" 2>/dev/null || echo 1)"
  if [ "$code" -ne 0 ] || grep -qE 'CAPTURE (FAIL|WARN)' "$OUT/$p.out"; then
    bad=$((bad + 1))
    printf 'SHOT %-14s ERROR    %s\n' "$p" "$(grep -vE '^(frames|mid|last|CAPTURE)' "$OUT/$p.out" | head -n 2 | tr '\n' ' ' | cut -c1-200)"
  fi
done
RESULT="$(bash tools/img.sh shots dir="$OUT" base="$BASE" out="$OUT" tol="${SHOT_TOL:-0.5}" ctol="${SHOT_CTOL:-2.0}" "${PRESETS[@]}")"
echo "$RESULT"
blank="$(echo "$RESULT" | grep -cE '^SHOT .* (BLANK|MISSING) ')"
changed="$(echo "$RESULT" | grep -cE '^SHOT .* CHANGED ')"
fresh="$(echo "$RESULT" | grep -cE '^SHOT .* NEW ')"
echo "SHOTS ${#PRESETS[@]} presets: $changed changed, $fresh new, $((bad + blank)) broken"
[ "$((bad + blank))" -eq 0 ]
