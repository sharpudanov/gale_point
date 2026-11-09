# Gale Point — Godot 4 3D game

- **Engine:** Godot 4.7.2-stable (standard, not .NET), Forward+. Binary path lives ONLY in
  `tools/env.sh` (`$GODOT`); scripts source it. Never hard-code the path elsewhere.
- **SPEC.md is the source of truth** for design and ART DIRECTION. Update it when decisions change.

## Code rules
- Godot 4 syntax only: `@export`/`@onready`, `await`, `super()`, `sig.connect(callable)`,
  `CharacterBody3D` + `velocity` — never Godot 3 (`export`, `yield`, `KinematicBody`, `connect("x", obj, "m")`).
- Static typing everywhere: typed vars, params, returns, typed arrays (`Array[Node3D]`).
- **Pure-code scenes:** `main.tscn` is a bare Node3D + `main.gd`. All other nodes, materials,
  environment, lights and UI are built in GDScript via `class_name` scripts in `res://src/`.
  Never hand-edit or create `.tscn` files for content.
- Tunables are `@export` vars (with sensible defaults), never magic numbers buried in logic.
- Shaders live in `.gdshader` files, loaded with `load()`; no inline shader code strings.
- `main.get_telemetry() -> Dictionary` must expose the state tests need (JSON-serializable).
- Shot presets: `main.gd` reads `--shot=<name>` (`BootArgs.get_value("shot")`) and jumps to that
  camera/storm state. Add a preset for every visual feature you want reviewed.
- Don't read `.godot/` or `*.import` (generated, denied).

## Automatic checks
- A PostToolUse hook (`tools/godot_check.sh`) parse-checks every edited .gd/.gdshader/.tres/.tscn
  headlessly. If it reports errors (exit 2), fix them before doing anything else.
- Manual: `tools/godot_check.sh --file <path>`.

## Tools
- `tools/sim.sh --plan=res://tests/plans/x.json --frames=600 --expect="path>=v"` — headless
  sim bot (`tests/sim_bot.gd`, plan schema in its header).
- `tools/capture.sh <preset> [frames]` — renders real frames to `.captures/<preset>/`.
- `tools/polyhaven.sh` — used by asset-fetcher only.

## Workflow per milestone
1. Implement (small steps; hook must stay green).
2. **playtester** agent: logic check with a fitting input plan + expectations.
3. **art-director** agent: visual check on the relevant shot presets. Apply its fixes;
   max 3 fix rounds, then move on and note leftovers in SPEC.md.
4. `git commit` with a clear message.

## Assets
- Only via the **asset-fetcher** agent (Poly Haven CC0, 1k–2k, into `res://assets/<type>/<name>/`,
  logged in `ASSETS.md`). No other sources, no manual downloads.
