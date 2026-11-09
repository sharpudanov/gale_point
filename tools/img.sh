#!/usr/bin/env bash
# Image helper (headless Godot, no GPU). See tools/img.gd for the commands:
#   tools/img.sh sheet out=<png> [cols=4] [cell=384x216] <label>=<png> ...   many frames in one labelled image
#   tools/img.sh diff <a.png> <b.png> [out=<png>]                            change metrics (+ a | b | diff image)
#   tools/img.sh stat <png>                                                  brightness of a frame
set -u
source "$(dirname "${BASH_SOURCE[0]}")/env.sh" || exit 3
cd "$PROJECT_ROOT" || exit 3
ensure_imported
mkdir -p .captures
"$GODOT" --headless --path "$PROJECT_ROOT" --log-file "$PROJECT_ROOT/.captures/img.engine.log" \
  --script res://tools/img.gd -- "$@" 2>&1 | grep -E '^(IMG_|SHOT |usage|SCRIPT ERROR|ERROR)'
exit "${PIPESTATUS[0]}"
