# Gale Point — Godot 4 3D game

- **Engine:** Godot 4.7.2-stable (standard, not .NET), Forward+. Binary path lives ONLY in
  `tools/env.sh` (`$GODOT`); scripts source it. Never hard-code the path elsewhere.
- **SPEC.md is the source of truth** for design and ART DIRECTION. Update it when decisions change.
  It is over 700 lines: `grep -n '^## \|^### ' SPEC.md` and Read only the sections you need.
- SPEC holds intent, rules and open issues. Numbers live in `@export` defaults, plans in `tests/`,
  assets in `ASSETS.md`: never copy them into SPEC. Section 14 lists open issues only; a closed issue is
  deleted, not annotated. `DESIGN_LOG.md` "Shipped Changes" keeps the last two iterations; older ones
  move to `docs/SPEC_HISTORY.md`, an archive you don't read unless asked.

## Code rules
- Godot 4 syntax only: `@export`/`@onready`, `await`, `super()`, `sig.connect(callable)`,
  `CharacterBody3D` + `velocity` — never Godot 3 (`export`, `yield`, `KinematicBody`, `connect("x", obj, "m")`).
- Static typing everywhere: typed vars, params, returns, typed arrays (`Array[Node3D]`). This is enforced:
  untyped declarations, calls or property access on a `Variant`, and shadowed names are parse errors
  (`[debug]` in `project.godot`). Give a Variant a type before using it (`var d: Dictionary = value`).
- **Scenes for things you look at, code for things that happen** (user decision, 2026-11-10: speed and
  results over purity). Anything that is placed, posed or styled (characters, viewmodel and hand holds,
  props, menus, HUD layout, effects worth tweaking by eye) lives in a `.tscn` under `res://scenes/`, so the
  user can drag and tune it in the Godot editor and Claude can edit it as text or through the godot-ai
  tools. Rules, state, AI, damage, waves and tests stay in `class_name` scripts under `res://src/`.
  Existing code-built content (ocean, weather, lighting, island, lighthouse) stays as it is until it needs
  visual work; then it moves to a scene instead of gaining more build code. A script finds its scene's
  nodes by name, so a scene can be rearranged without touching code.
- `map/layout.tscn` is the single source of positions (`MapLayout`): Marker3D braziers, casks, winch and
  buoys plus rock glTF instances. Check edits with `tools/capture.sh map 2` and `layout.problem_count`.
  After the island shape changes, refresh `map/preview/map.png` (last frame of
  `tools/capture.sh map 2 --map_plain`).
- After adding or renaming a script or scene while the editor is open, read the editor console
  (`logs_read source="editor"`): the headless check passing does not mean the editor has caught up.
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

## Who decides (user, 2026-11-10: "I told you you are free to change")
- Claude owns the workflow, the rules in this file, the tools, skills and agents, and the game's design.
  When something slows the game down or wastes tokens, change it and say so in one line; do not ask
  first and do not park it. Only destructive or outward-facing steps (deleting the user's work,
  force-push, publishing a build) still need a yes.
- The goal is the game, judged by playing it. Tooling work must pay for itself in the same session.
  Adopt an existing addon, template or asset pack before building one. After changing `tools/` or the
  hooks, run `tools/selftest.sh --fast`.
- The user plays and tunes in the editor; Claude builds systems and fixes. Ask for a five-minute play
  session and three notes rather than judging feel from still frames.

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
- `tools/export_scene.sh [debug args]` — saves the code-built game tree as `res://snapshot/game.tscn`
  (gitignored) to inspect in the Godot editor. Scripts and audio stripped: a snapshot, not the game.

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

## godot-ai MCP (the live editor; use it when the editor is open)
- Use it for what it is good at: reading the editor console, building and adjusting scenes and nodes,
  screenshots of the editor or the running game, running and stopping the game. It beats rendering
  frames to check a placement. If `editor_state` fails the editor is closed: fall back to text edits and
  the headless tools without comment.
- Running the game opens a window on the user's desktop; stop what you start with
  `project_manage(op="stop")`.
- Scripts are still written with Edit / Write (the gates check them), not with the MCP script tools.
- `addons/godot_ai/` is third-party: never edit it. Its `_mcp_game_helper` autoload is the only one in
  the project and game code never references it. `project.godot` belongs to the editor while it is open.
  `.mcp.json` is per-machine and gitignored (Godot AI dock → Configure writes it).

## Skills (.claude/skills/, tested templates inside; load the one that fits BEFORE the work, not after a failure)
- **godot-models**: no modelling in code; placeholder budget, model brief for the user, glTF intake and wiring.
- **gdscript-craft**: strict-typing error -> fix table, which script to copy, small-file structure, token habits.
- **game-feel**: diagnosis for "feels weak / plays badly", feedback layers and ranges, one sweep + one human question.
- **godot-ui**: code-built HUD, menus, pause, cards, settings file.
- **godot-ship**: export setup, build command, release checklist, store page (not yet run here).
- **godot-ocean-weather**: Gerstner ocean shader + matching GDScript height, foam, mist, rain, lightning.
- **moody-lighting**: AgX/fog/SSAO/sun/beam starting values, warm-vs-cold rule, never-list.

## Workflow per milestone (`/iterate` runs the gameplay loop)
0. Played first. If no human play session is newer than the last game change, the work is a polish
   cycle: open issues from SPEC.md section 14, no new mechanic. One new mechanic per cycle at most.
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
- Hands, holds, attachments and poses are set in a scene (editor or godot-ai), not by guessing numbers
  in code and rendering frames.
- **Claude never builds 3D models in code** (no SurfaceTool / ArrayMesh / CSG, no shapes assembled from
  many primitives). Allowed: a placeholder of at most 3 built-in primitives, and systems (terrain, ocean,
  sky, particles). Existing code-built models (`DrownedBuilder`, viewmodel hands) are frozen: bug fixes
  only. Anything that needs a real shape is a model brief for the user (godot-models skill).
- Claude adds assets only via the **asset-fetcher** agent, CC0 only, into `res://assets/<type>/<name>/`,
  logged in `ASSETS.md`: Poly Haven (props, textures, HDRIs, 1k–2k) and CC0 pages on OpenGameArt
  (characters, animations). No login-only sites, no other licences.
- Humanoid motion comes from `res://assets/animations/ual1|ual2/` (Quaternius, a rigged mannequin with
  about 90 clips). Animate with those clips before writing any procedural body animation.
- The user may drop their own `.glb` into `res://assets/models/<name>/`; Claude inspects it with the
  godot-models skill and adds the `ASSETS.md` row (source and licence from the user).
