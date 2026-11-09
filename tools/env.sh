#!/usr/bin/env bash
# Single source of truth for tool paths. Every script in tools/ and tests/ sources this.
# Override per-machine by exporting GODOT before calling any script.
GODOT="${GODOT:-/c/Users/huhub/Tools/Godot/Godot_v4.7.2-stable_win64.exe}"
GODOT_VERSION="4.7.2-stable"

# Project root = parent of tools/ (works no matter where the caller's cwd is).
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -x "$GODOT" ]; then
  echo "env.sh: Godot binary not found at: $GODOT" >&2
  return 1 2>/dev/null || exit 1
fi

# Make sure the .godot/ cache (global class_name table, imports) exists.
ensure_imported() {
  if [ ! -f "$PROJECT_ROOT/.godot/global_script_class_cache.cfg" ] || [ "${1:-}" = "force" ]; then
    "$GODOT" --headless --path "$PROJECT_ROOT" --import >/dev/null 2>&1 || true
  fi
}
