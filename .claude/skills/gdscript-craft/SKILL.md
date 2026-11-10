---
name: gdscript-craft
description: ALWAYS use before writing a new .gd file or a new system (enemy, weapon, interactable, pickup, manager) in this Godot 4.7 project, when the check gate reports a GDScript parse, type, "unsafe" or "shadowed" error, and before adding to a script that is already over 400 lines. Lists the strict-typing errors this project turns into parse errors with their one-line fixes, which existing script to copy for each kind of feature, the structure rules that keep files small, and the habits that keep a task cheap in tokens.
---

# GDScript craft: right the first time, in small files

A failed gate costs a round trip. A file over 400 lines costs tokens every time it is read. Both are
avoidable.

## 1. Strict typing: error -> fix
`project.godot` makes these parse errors: untyped declaration, unsafe property / method access,
shadowed variable (also a base-class member), narrowing conversion, unreachable code, standalone expression.

| You wrote | Write instead |
|---|---|
| `var x = ...`, `func f(a)`, `func(v): return v` | `var x: T = ...`, `func f(a: T) -> R`, `func(v: T) -> R: return v` |
| `var s := load(p)` then `s.instantiate()` | `var s: PackedScene = load(p) as PackedScene`, then `s.instantiate() as Node3D` |
| `get_node("X").foo`, `get_child(0).foo`, `find_child("X").foo`, `get_parent().foo` | cast first: `var x: Foo = get_node("X") as Foo` |
| `dict["k"].foo`, `arr[i].foo` on an untyped container, `JSON.parse_string(s)["k"]` | give it a type: `var d: Dictionary = v`, `var f: float = float(d["k"])`, `str(d["k"])` |
| `var m := min(a, b)` (also `max` `clamp` `lerp` `abs` `sign` `floor` `round`: they return Variant) | `minf` `maxf` `clampf` `lerpf` `absf` `signf` `floorf` `roundf`, or `mini` `maxi` `clampi` `absi` |
| `var n: int = some_float` | `int(x)`, `roundi(x)`, `floori(x)` |
| a local or parameter named `name`, `position`, `scale`, `rotation`, `owner`, `visible`, `process_mode`, or like any member of the class or its bases | another name (`label`, `pos`, `factor`, `host`) |
| a bare `a == b` or `foo` line; code after `return` | delete it |

(Checked against the gate on 2026-11-10. `for i in 3:` is fine: the loop variable is inferred.)

Runtime traps the gate does not catch:
- `var a: Array[Foo] = untyped.filter(...)` parses but fails when it runs (also `map`,
  `get_nodes_in_group()`): `var a: Array[Foo] = []`, then `a.assign(...)`.
- `_ready()` runs inside `add_child()`. Set every property the node's `_ready()` reads **before** adding it.
- A node kept across an `await` or in a list may be freed: `is_instance_valid(n)` before use.
- A one-shot effect frees itself (`finished.connect(queue_free)`, or a timer); never leave it to the parent.
- A tween from `create_tween()` dies with its node; one from `get_tree().create_tween()` does not.
- Randomness: its own `RandomNumberGenerator` or `GameRng`, never `randf()` (sims are seeded).
- Engine enums in full: `GeometryInstance3D.SHADOW_CASTING_SETTING_OFF`, `Animation.LOOP_LINEAR`.
- Not sure of a name or a signature? `tools/api.sh <Class> <filter>` costs 5 lines. Guessing costs a round.

## 2. Copy the nearest working script (outline it with `tools/api.sh <ClassName>`, read only the part you need)
| Building | Start from |
|---|---|
| glTF prop with a collider that can be shot and burned | `src/world/oil_cask.gd` |
| enemy variant on top of `Drowned` | `src/enemies/captain_lantern.gd` |
| looping particles (flame, smoke) or a burst | `src/fx/fire_fx.gd` |
| one-shot hit / splash effect | `src/fx/hit_fx.gd` |
| a light that counts for gameplay | `src/combat/game_light.gd`, `src/combat/light_field.gd` |
| world object the player uses | `src/world/beam_winch.gd`, `src/world/ammo_crate.gd` |
| a synthesized sound | `src/audio/proc_audio.gd`, played through `src/audio/soundscape.gd` |
| HUD element | `src/fx/reticle.gd`, a `Control` inside `PostFx` (see the godot-ui skill) |
| a part of an imported model that moves | `ViewmodelBuilder.rifle()` (see the godot-models skill) |
| a debug key or a staged scenario | `src/core/sandbox.gd`, `src/core/debug_args.gd` |

## 3. Structure
- One script, one job, about 300 lines. Before adding a feature to a script over 400 lines, move one seam
  out first (effects, building, telemetry, one state's logic) as its own commit with the suite green.
  Never refactor a file the task does not touch.
- Calls go down the tree, signals go up. Siblings meet through their parent (`main.gd`) or a group.
- State machine: one `enum State`, one `_enter(state)` and one `match` in `_tick(delta)`, with the time in
  state in `_state_t`. No node or class per state.
- A rule lives in one place as a static function (`HitGeo`, `FireSystem`) and is extended, not copied
  (Learned Principle 5 in `DESIGN_LOG.md`).
- Every new thing: `class_name` script in `src/<area>/`, tunables as `@export`, its state in
  `main.get_telemetry()`, a plan + `tests/suite.txt` line if it is a rule, a `--shot` preset if it is visible.

## 4. Token habits
- Outline before reading: `tools/api.sh <ProjectClass>` gives line numbers; then Read with `offset` /
  `limit`. Grep for a symbol instead of reading a file to find it.
- Edit the smallest hunk that is unique. Never rewrite a file to change one function; never read a file
  back after an Edit (the gate already checked it).
- Independent lookups go out together in one message.
- A value that is a matter of degree is found with one sweep, not by edit / capture rounds.
- Images: sheet, strip or pair before a full frame; one full frame at most per question.
- Subagents only where CLAUDE.md names them (asset-fetcher, art-director, game-director).
- Stop at "works, gates green, committed". Polish beyond the request is a line under Next Horizon.
