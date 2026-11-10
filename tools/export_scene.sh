#!/usr/bin/env bash
# Save the game tree that main.gd builds in code as a real scene to open in the Godot editor.
#   tools/export_scene.sh [debug args...]        e.g. tools/export_scene.sh --shot=calm
#   tools/export_scene.sh --export_scene=res://snapshot/storm.tscn --night_t=270
# Default output: res://snapshot/game.tscn (gitignored; overwritten every run). A snapshot for looking:
# scripts and procedural audio are stripped, so running it does nothing. See src/harness/scene_exporter.gd.
source "$(dirname "${BASH_SOURCE[0]}")/env.sh" || exit 1
cd "$PROJECT_ROOT" || exit 1
ensure_imported
mkdir -p .captures
ARGS=("$@")
case " $* " in *" --export_scene"*) ;; *) ARGS+=("--export_scene") ;; esac
timeout 180 "$GODOT" --headless --path "$PROJECT_ROOT" --log-file "$PROJECT_ROOT/.captures/export_scene.engine.log" \
  -- "${ARGS[@]}" >.captures/export_scene.log 2>&1
CODE=$?
grep -E '^export_scene:|SCRIPT ERROR|^ERROR' .captures/export_scene.log | awk '!seen[$0]++' | head -n 12
exit $CODE
