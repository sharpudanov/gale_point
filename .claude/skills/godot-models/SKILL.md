---
name: godot-models
description: ALWAYS use before giving anything a 3D shape in this Godot 4.7 project - a new or reworked enemy, character, creature, weapon, hand, prop, pickup or piece of architecture - and before touching SurfaceTool, ArrayMesh, ImmediateMesh, CSG, a `*_builder.gd` script, or an art-director note about a model's shape or silhouette. Also use when the user drops a .glb / .gltf into assets/, or when wiring an imported model's scale, materials, collision or animations. Holds the hard rule (Claude does not model in code), the placeholder budget, the model brief for the user, and tested import helpers.
---

# 3D models: bring them in, never build them

**Rule (user, 2026-11-10): Claude does not make 3D models in code here.** No SurfaceTool / ArrayMesh /
lathe profiles / CSG, no sculptures assembled from many primitives, no vertex shader that fakes a shape.
A model built in code costs thousands of tokens per art round and still reads as programmer art.

- Existing code-built models (`DrownedBuilder`, the viewmodel hands) are **frozen**: bug fixes only, no
  shape work. They get replaced when a real model arrives.
- Systems are not models and stay in code: terrain heightfield, ocean, sky, particles, decals, lights.
- An art-director note about a model's *shape* is answered with a brief for the user, never a code fix.

## What to do when something needs a shape
1. **Reuse.** Check `ASSETS.md`. A tint, a scale or two whole models parented together is fine.
2. **Fetch it** with the asset-fetcher agent (CC0 only). Props, rocks, tools, furniture, plants: Poly
   Haven, with an exact slug when you know one. Characters, creatures, animations: a CC0 page on
   OpenGameArt (give it the page URL or a plain description).
3. **Otherwise: placeholder now, brief to the user, move on.** Gameplay does not wait for art.

## Animated humanoids: start from what is installed
`res://assets/animations/ual1/ual1.glb` and `ual2/ual2.glb` (Quaternius, CC0) are one rigged 1.83 m
mannequin (13.7k triangles, node path `*/Skeleton3D/Mannequin`, own `AnimationPlayer`). Useful clips:
- ual1: `Idle` `Walk` `Jog_Fwd` `Sprint` `Crouch_Idle` `Crouch_Fwd` `Hit_Chest` `Hit_Head` `Death01`
  `Swim_Fwd` `Swim_Idle` `Idle_Torch` `Push` `Punch_Jab` `Sword_Attack` `Interact`
- ual2: `Zombie_Idle` `Zombie_Walk_Fwd` `Zombie_Scratch` `Hit_Knockback` `Idle_Lantern` `Melee_Hook`
  `ClimbUp_1m_RM` `LayToIdle` `OverhandThrow` `Walk_Carry`
The two files have different skeletons (53 and 65 bones), so one body plays clips from one file only;
pick the file by the clips the creature needs. A humanoid enemy is the mannequin from that file with
its materials replaced (`set_surface_override_material`, or the project's cloth shader as
`material_override`), driven by its own `AnimationPlayer`. Clips ending in `_RM` move the root: avoid
them, code moves the body. A different character mesh can use these clips only if it is skinned to the
same skeleton; retargeting another rig is editor work for the user, not code.

## Placeholder budget
At most 3 built-in primitives (`BoxMesh`, `CapsuleMesh`, `CylinderMesh`, `SphereMesh`, `QuadMesh`), one
flat material, about 25 lines, sized to the real collision volume. No art-director round, no sweep and no
shot preset for a placeholder. Build it in a `_build_placeholder()` that runs only when `ModelKit.spawn()`
returns null, so the real file replaces it without a code change.

## Model brief (put it in the reply, and as an open issue in SPEC.md section 14)
```
MODEL WANTED: <name>  ->  assets/models/<name>/<name>.glb
Role: <what it is, how close and how many the player sees>
Size: <h> x <w> x <d> m. 1 unit = 1 m, Y up, faces -Z, origin at <feet | grip | base centre>
Budget: <tris> triangles, 1 material, 1k PBR textures (2k for a hero) embedded in the .glb
Separate parts: <objects that move on their own, each with its pivot at the hinge>
Rig and clips: <none | clip names, which ones loop, rough lengths>
Look: <one line from SPEC.md section 13 plus what the silhouette must say>
Licence: CC0 or made / owned by you
```
Budgets: enemy seen in groups 10k, first-person weapon 20k (the rifle is 20k), prop 5k.
Where the user can get what the fetcher cannot (login-only sites): Sketchfab "CC0" filter, Mixamo, an
image-to-3D generator, or Blender. The user records source and licence; Claude adds the `ASSETS.md` row.

## Intake: a file arrived
```bash
source tools/env.sh && ensure_imported force
"$GODOT" --headless --path . --script .claude/skills/godot-models/templates/model_info.gd -- res://assets/models/<name>/<file>.glb
```
Prints the size in metres, node tree, triangles, materials, bones and clips in about 15 lines. Never Read
a `.gltf`, `.glb`, `.bin` or `.import`. If size, facing or clips are far off the brief, tell the user what
to fix in the source file; a wrong scale or a 90 degree turn is fixed in code.

## Wiring (pure code)
Install `templates/model_kit.gd` as `res://src/core/model_kit.gd` (`class_name ModelKit`, tested here on
4.7.2): `spawn(path)`, `fit_height(model, metres)`, `bounds(model)`, `meshes(model)`, `tint(model, colour)`,
`animation_player(model)`, `set_loops(ap, clips)`.
```gdscript
const MODEL: String = "res://assets/models/<name>/<name>.glb"
@export var model_height: float = 1.9

func _build_model() -> void:
	var pivot: Node3D = Node3D.new()          # rotate / animate the pivot, never the imported root
	pivot.name = "Model"
	add_child(pivot)
	var model: Node3D = ModelKit.spawn(MODEL)
	if model == null:
		_build_placeholder(pivot)
		return
	pivot.add_child(model)
	ModelKit.fit_height(model, model_height)
	_anim = ModelKit.animation_player(model)
	if _anim != null:
		ModelKit.set_loops(_anim, PackedStringArray(["idle", "walk"]))
		_anim.play("idle")
```
- **The model is cosmetic.** Collision, hitboxes and hit tests stay code shapes on the script's root
  (capsule, cylinder, `HitGeo`), so sims pass with or without the file and animation never moves a hitbox.
- **Animation:** `_anim.play(clip, 0.2)` blends over 0.2 s; walk speed follows velocity through
  `_anim.speed_scale`. Damage, spawn and death timing come from code timers, never from a clip's length
  or an animation event. `AnimationTree` only when two clips must blend at once (walk + aim).
- **Attach to a bone:** `BoneAttachment3D` under the `Skeleton3D`, set `bone_name`, parent the prop to it.
- **Parts that move** (bolt, lid, door): re-parent the named mesh under a pivot at the hinge, as
  `ViewmodelBuilder.rifle()` does with the bolt.
- **Materials:** keep the model's PBR materials. Per-instance changes go through a duplicate in
  `set_surface_override_material` (`ModelKit.tint`), a whole-body effect (dissolve, searing) through
  `material_overlay`. No shadows from small props: `cast_shadow` off.
- **Static world collision** for a rock or wall: `mesh.create_convex_shape()`; `create_trimesh_shape()`
  only for large static pieces the player walks on.
- Then: one `--shot` preset for the model in play, one art-director round, `tools/bench.sh` if many
  instances are on screen.
