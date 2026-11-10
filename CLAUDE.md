# Gale Point — Godot 4 3D game

- **Engine:** Godot 4.7.2-stable (standard, not .NET), Forward+. Binary path lives ONLY in
  `tools/env.sh` (`$GODOT`); scripts source it. Never hard-code the path elsewhere.
- **SPEC.md is the source of truth** for design and ART DIRECTION. Update it when decisions change.
  It is over 1,000 lines: `grep -n '^## \|^### ' SPEC.md` and Read only the sections you need.

## Code rules
- Godot 4 syntax only: `@export`/`@onready`, `await`, `super()`, `sig.connect(callable)`,
  `CharacterBody3D` + `velocity` — never Godot 3 (`export`, `yield`, `KinematicBody`, `connect("x", obj, "m")`).
- Static typing everywhere: typed vars, params, returns, typed arrays (`Array[Node3D]`). This is enforced:
  untyped declarations, calls or property access on a `Variant`, and shadowed names are parse errors
  (`[debug]` in `project.godot`). Give a Variant a type before using it (`var d: Dictionary = value`).
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
- Change files with Edit / Write, not with python or sed patch scripts (more tokens, checked later).
- Don't read `.godot/` or `*.import` (generated, denied).

## Gates (automatic; when one reports, fix that before anything else)
| When | Runs | Catches |
|---|---|---|
| every Edit / Write of a `.gd` / `.gdshader` | `tools/godot_check.sh` | parse, type and shader errors in any project script |
| every Bash / PowerShell call | `tools/godot_check.sh --changed` | the same, for files a command changed |
| end of every turn | `tools/gate.sh` | a red `tools/sim.sh --all` after files changed (runs it, about 30 s) |

`tools/selftest.sh [--fast]` injects faults and proves the gates and tools still work. Run it after
changing `tools/`, the hooks, `tests/sim_bot.gd` or the `[debug]` settings.

## Harness freeze (the goal is shipping the game)
- `tools/`, the hooks, `tests/sim_bot.gd` and `.claude/agents|commands|skills` change only for a failure
  that happened twice. One change at a time, the failure named in the commit message, then
  `tools/selftest.sh --fast`.
- A harness idea without such a failure is one line under Next Horizon in `DESIGN_LOG.md`, not code.
- Adopt before building. An engine bridge with breakpoints and live inspection already exists
  (gdharness; it would replace godot-ai). Try it on a branch when a runtime bug survives two attempts
  with `sim.sh` + telemetry, instead of writing new debugging tools.

## Tools (run them yourself; their output is already compact)
Logic
- `tools/sim.sh --plan=res://tests/plans/x.json --frames=600 --expect="path>=v"` — headless sim bot
  (`tests/sim_bot.gd`, plan schema in its header). `tools/sim.sh --all [name...]` runs `tests/suite.txt`
  in parallel (about 30 s).

Eyes (read the cheapest image that answers the question: sheet, strip or pair before full frames)
- `tools/capture.sh <preset> [frames] [--set=...]` — real frames in about 9 s. Prints `mid` / `last`
  (full resolution), `strip` (6 frames over time in one image) and `pair` (previous capture | this one |
  difference).
- `tools/shots.sh [preset...]` — visual regression: every preset against this machine's baseline in
  about 35 s. SAME / CHANGED (with a pair image) / NEW / BLANK / ERROR plus one contact sheet. Look only
  at what changed; `tools/shots.sh --accept` once the changes are the intended ones.
- `tools/sweep.sh <preset> <Class.property> v1 v2 [v3 v4]` — several values of a tunable side by side in
  one image. Use it for anything that is a matter of degree instead of guess / capture / guess rounds.
- `tools/img.sh sheet|diff|stat` — your own contact sheet, or a comparison of two frames.

Numbers
- `tools/bench.sh [preset]` — real frame rate of a preset against this machine's baseline.
- `--set=Class.property=value` on `sim.sh` / `capture.sh` — try a tunable without editing code.
  Experiments only: never in `tests/suite.txt` or `ShotPresets`.

Knowledge
- `tools/api.sh <Class> [filter]` — exact Godot 4.7.2 properties, signatures and enums for an engine
  class, or a line-numbered outline of a project class. Use it before guessing an API and before reading
  a whole file.
- `tools/evidence.sh` — what the human saw: newest P/F12 screenshots, a digest of the newest play
  session, the contact sheet and recent frames. `SessionLog` (`src/harness/session_log.gd`) records every
  windowed normal-play run to `.captures/sessions/` (timeline, P bookmarks, frame rate, errors).
- `tools/polyhaven.sh` — used by asset-fetcher only.

## godot-ai MCP (optional, live debugging only)
- The harness works with the editor closed; nothing above needs the MCP. Never wait on it or use it as
  a check. If `editor_state` fails, skip it silently.
- Use it only when the user asks to debug the running game (`project_run`, `editor_manage` `game_eval`,
  `game_manage`, `editor_screenshot source="game"`). Those open a window on the user's desktop, so they
  prompt; stop what you start with `project_manage(op="stop")`.
- Scene / node / resource / script / filesystem / test tools are denied in `.claude/settings.json`:
  content is pure code. Don't work around the list.
- `addons/godot_ai/` is third-party: never edit it. Its `_mcp_game_helper` autoload is the only one in
  the project and game code never references it. `project.godot` belongs to the editor while it is open.
  `.mcp.json` is per-machine and gitignored (Godot AI dock → Configure writes it).

## Skills (.claude/skills/, tested templates inside)
- **godot-ocean-weather**: Gerstner ocean shader + matching GDScript height, foam, mist, rain, lightning.
- **moody-lighting**: AgX/fog/SSAO/sun/beam starting values, warm-vs-cold rule, never-list.

## Workflow per milestone (`/iterate` runs the gameplay loop)
1. Implement (small steps; the gates stay green). Checkpoint: `git commit` locally after every step that
   leaves the gates green, so a session cut off by the usage limit loses nothing. A new session resumes
   from `git log -5` and Next Horizon in `DESIGN_LOG.md`.
2. Logic: add a plan + a `tests/suite.txt` line for every new rule; `tools/sim.sh --all`.
3. Look: `tools/shots.sh`, then the **art-director** agent on the presets that matter. Apply its fixes;
   one fix round by default (up to 3 when the user asks for a polish pass), then move on and note
   leftovers in SPEC.md.
4. `git commit` with a clear message, then `git push` to `origin main` (GitHub:
   `sharpudanov/gale_point`). Project is worked on from two machines (desktop + laptop):
   start of a session = `git pull --ff-only`; end of a milestone = commit + push.
   Never force-push or rewrite history without the user asking. Git identity is
   `sharpu <uvaysbazaev1@gmail.com>`; don't change it.
   Machine-specific `tools/env.sh` (Godot path) must not be committed from the laptop.

## Assets
- Only via the **asset-fetcher** agent (Poly Haven CC0, 1k–2k, into `res://assets/<type>/<name>/`,
  logged in `ASSETS.md`). No other sources, no manual downloads.
