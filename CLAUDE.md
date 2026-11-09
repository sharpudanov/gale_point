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
- **Tests follow rules.** When a rule changes on purpose, update the plan's `--expect` and SPEC in the
  same commit. Debug flags (`--freeze_enemies`, `--no_waves`, ...) only stage a scenario; never branch a
  game rule on one to keep an old expectation green.
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
- `tools/evidence.sh` — what the human saw: newest P/F12 screenshots, a digest of the newest play
  session and recent rendered frames. `SessionLog` (`src/harness/session_log.gd`) records every windowed
  normal-play run to `.captures/sessions/` (timeline, P bookmarks with telemetry, frame rate, errors).
- `tools/polyhaven.sh` — used by asset-fetcher only.

## godot-ai MCP (optional inspection lane, never a gate)
- The harness must work with the editor closed (laptop, subagents). The hook, `sim.sh` and `capture.sh`
  are the only checks that count: never replace or repeat one with an MCP call, never wait on the MCP.
- It needs the Godot editor open with the Godot AI plugin. If `editor_state` fails, skip it silently.
- Use it for what the scripts cannot do: `api_manage(op="get_class")` for exact 4.7.2 signatures,
  properties and enums; and live debugging when asked (`project_run`, `editor_manage` `game_eval`,
  `game_manage`, `editor_screenshot source="game"`). Those open a window on the user's desktop, so they
  prompt; stop what you start with `project_manage(op="stop")`.
- Scene / node / resource / script / filesystem / test tools are denied in `.claude/settings.json`:
  content is pure code, and MCP script writes would skip the parse hook. Don't work around the list.
- `addons/godot_ai/` is third-party: never edit it. Its `_mcp_game_helper` autoload is the only one in
  the project and game code never references it. `project.godot` belongs to the editor while it is open.
  `.mcp.json` is per-machine and gitignored (Godot AI dock → Configure writes it).

## Skills (.claude/skills/, tested templates inside)
- **godot-ocean-weather**: Gerstner ocean shader + matching GDScript height, foam, mist, rain, lightning.
- **moody-lighting**: AgX/fog/SSAO/sun/beam starting values, warm-vs-cold rule, never-list.

## Workflow per milestone
1. Implement (small steps; hook must stay green).
2. **playtester** agent: logic check with a fitting input plan + expectations.
3. **art-director** agent: visual check on the relevant shot presets. Apply its fixes;
   max 3 fix rounds, then move on and note leftovers in SPEC.md.
4. `git commit` with a clear message, then `git push` to `origin main` (GitHub:
   `sharpudanov/gale_point`). Project is worked on from two machines (desktop + laptop):
   start of a session = `git pull --ff-only`; end of a milestone = commit + push.
   Never force-push or rewrite history without the user asking. Git identity is
   `sharpu <uvaysbazaev1@gmail.com>`; don't change it.
   Machine-specific `tools/env.sh` (Godot path) must not be committed from the laptop.

## Assets
- Only via the **asset-fetcher** agent (Poly Haven CC0, 1k–2k, into `res://assets/<type>/<name>/`,
  logged in `ASSETS.md`). No other sources, no manual downloads.
