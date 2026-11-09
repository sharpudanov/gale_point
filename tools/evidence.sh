#!/usr/bin/env bash
# Evidence from the last human playtest, for /iterate step 1 and the game-director (which cannot run commands).
#   tools/evidence.sh [n=4]
# Prints: the newest P / F12 screenshots, a digest of the newest SessionLog file (src/harness/session_log.gd:
# every line except the periodic "snap" breadcrumbs, each cut to its compact front part), and the mid frame
# of the n most recently captured shot presets. Paths are absolute, ready for the Read tool; Read the
# .jsonl itself for the full telemetry behind a "mark" or "end" line.
set -u
N="${1:-4}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 3
abs() { cygpath -m "$ROOT/$1" 2>/dev/null || printf '%s\n' "$ROOT/$1"; }
stamp() { date -r "$1" '+%Y-%m-%d %H:%M' 2>/dev/null; }

echo "== LAST COMMIT (evidence older than this predates the current build)"
git log -1 --format='%cd  %s' --date=format:'%Y-%m-%d %H:%M' 2>/dev/null || echo "unknown"

echo "== SCREENSHOTS (P / F12, newest first)"
mapfile -t SHOTS < <(ls -t .captures/screenshots/*.png 2>/dev/null | head -n 3)
[ "${#SHOTS[@]}" -eq 0 ] && echo "none"
for f in "${SHOTS[@]}"; do
  echo "$(stamp "$f")  $(abs "$f")"
done

echo "== SESSION LOG (newest human play session)"
LOG="$(ls -t .captures/sessions/session_*.jsonl 2>/dev/null | head -n 1)"
if [ -z "$LOG" ]; then
  echo "none yet (play the game in a window once; SessionLog writes .captures/sessions/session_<unix>.jsonl)"
else
  echo "$(stamp "$LOG")  $(abs "$LOG")"
  grep -v '"type":"snap"' "$LOG" | cut -c1-"${EVIDENCE_LINE_MAX:-1500}" | head -n "${EVIDENCE_MAX_LINES:-40}"
  if ! grep -q '"type":"end"' "$LOG"; then
    echo "(no end line: the game was stopped hard or crashed; last breadcrumb:)"
    grep '"type":"snap"' "$LOG" | tail -n 1
  fi
fi

echo "== RENDERED PRESET FRAMES (most recent captures, mid frame)"
count=0
while read -r d; do
  d="${d%/}"
  name="$(basename "$d")"
  case "$name" in screenshots|sessions|sim|test|rv|skilltest*) continue ;; esac
  mapfile -t PNGS < <(ls "$d"/f*.png 2>/dev/null | sort)
  [ "${#PNGS[@]}" -eq 0 ] && continue
  echo "$(stamp "${PNGS[0]}")  $name  $(abs "${PNGS[$(( ${#PNGS[@]} / 2 ))]}")"
  count=$((count + 1))
  [ "$count" -ge "$N" ] && break
done < <(ls -dt .captures/*/ 2>/dev/null)
[ "$count" -eq 0 ] && echo "none"
exit 0
