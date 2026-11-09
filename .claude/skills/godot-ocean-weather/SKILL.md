---
name: godot-ocean-weather
description: ALWAYS use when building or changing the ocean, waves, water shader, buoyancy / floating objects, wave height queries, sea foam, water color/depth, sea mist or fog volumes, rain, wind, lightning, or any storm effect in this Godot 4.7 project. Provides render-tested Gerstner ocean (shader + identical GDScript height function), crest/shore foam, Fresnel, depth absorption, FogVolume mist, wind-angled GPU rain and lightning flashes.
---

# Godot 4.7 ocean & storm weather

Every snippet here was hook-checked, rendered with `tools/capture.sh` and numerically tested on
Godot 4.7.2 (Forward+). APIs verified against docs.godotengine.org/en/4.7 + `--doctool` dump.

## Install (copy, then adapt — do not rewrite from memory)
| Template (in this skill's `templates/`) | Copy to | class_name |
|---|---|---|
| `ocean.gdshader` | `res://shaders/ocean.gdshader` | — |
| `ocean.gd` | `res://src/world/ocean.gd` | `Ocean` (MeshInstance3D) |
| `storm_weather.gd` | `res://src/world/storm_weather.gd` | `StormWeather` (Node3D) |
Lighting/environment values live in the **moody-lighting** skill (`MoodRig`); the mist needs its
`Environment.volumetric_fog_enabled = true`.

## The CPU/GPU contract (why heights match exactly)
- Shader uses `render_mode world_vertex_coords` → waves are sampled in **world XZ**; GDScript
  `displacement(p, t)` uses world XZ too. Never subtract the node position on one side only.
- **Time is a uniform**, pushed from `Ocean._process` (`wave_time`), never shader `TIME`:
  `TIME` rolls over at `rendering/limits/time/time_rollover_secs` (3600) and ignores pause.
- Waves are `PackedVector4Array` → `uniform vec4 waves[4]` (x,y dir · z steepness · w wavelength m).
  Keep steepness sum < 1 (default 0.58) or crests self-intersect.
```gdscript
for w: Vector4 in waves:                      # Ocean.displacement(p, t) — mirrors gerstner()
	var k: float = TAU / w.w
	var c: float = sqrt(G / k)                # deep-water dispersion, G = 9.81
	var d: Vector2 = Vector2(w.x, w.y).normalized()
	var f: float = k * (d.dot(p) - c * t)
	var a: float = w.z / k
	out += Vector3(d.x * a * cos(f), a * sin(f), d.y * a * cos(f))
```
- `Ocean.get_height(x, z, iterations = 4)` inverts the sideways Gerstner shift by fixed-point
  iteration. **Measured** worst XZ error (default waves): 2 it 11 cm · 4 it 1.3 cm · 6 it 1.5 mm.
  Use 4 for gameplay, 6+ for camera/visual contact. Analytic normal vs finite difference: < 0.25°.

## Shader features (ocean.gdshader) and their tuning uniforms
| Feature | How | Uniforms (default) |
|---|---|---|
| Normal | analytic tangent/binormal sums, `NORMAL = normalize(cross(binormal, tangent))` | — |
| Crest foam | Jacobian `1 - (T.x*B.z - T.z*B.x)` → high where the surface compresses/folds | `foam_threshold` 0.3 (≈0.5 × steepness sum), `foam_softness` 0.15 |
| Shore foam | `1 - smoothstep(0, width, water_depth)` around anything piercing the water | `shore_foam_width` 0.6 |
| Fresnel | `pow(1 - dot(NORMAL, VIEW), p)` mixes body → `sky_reflect_color` | `fresnel_power` 5 |
| Depth absorption | `exp(-absorption * water_depth)`, red dies first | `absorption` (0.45, 0.12, 0.09) |
| Refraction | `hint_screen_texture` offset by `NORMAL.xz` | `refraction_strength` 0.04 |
Linear depth (Forward+, reverse-Z, from the 4.7 "Advanced post-processing" docs):
```glsl
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
float linear_depth(vec2 uv, float raw, mat4 inv_proj) {   // pass INV_PROJECTION_MATRIX in!
	vec3 ndc = vec3(uv * 2.0 - 1.0, raw); // Forward+/Mobile (reverse-Z)
	vec4 v = inv_proj * vec4(ndc, 1.0);
	return -v.z / v.w;
}
// in fragment():
float scene_depth = linear_depth(SCREEN_UV, texture(depth_tex, SCREEN_UV).r, INV_PROJECTION_MATRIX);
float water_depth = max(scene_depth - (-VERTEX.z), 0.0);
```
Writing `ALPHA = 1.0` puts the water in the transparent pass so the screen/depth textures contain
the opaque scene; `depth_draw_always` keeps it in the depth buffer. Transparent objects never
appear in those textures (docs).

## Storm (storm_weather.gd)
- **Rain**: `GPUParticles3D` + `ParticleProcessMaterial` (`EMISSION_SHAPE_BOX`, `direction` =
  normalized `(wind.x, -fall, wind.z)`, `gravity = Vector3.ZERO`, spread 2°), `QuadMesh` 0.015×0.6,
  unshaded alpha 0.28, and **`transform_align = TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY`** →
  camera-facing streaks slanted by the wind. Emitter upwind (`-wind * 0.7`) and 18 m up;
  `preprocess = lifetime` so it is already raining on frame 1; parent it to the camera rig.
- **Mist**: `FogVolume` box 240×8×240, `FogMaterial` density 0.03, albedo (0.62, 0.68, 0.72),
  `height_falloff` 0.35 (thick at the water), `edge_fade` 0.3. Forward+ only.
- **Lightning**: dedicated cold `DirectionalLight3D` (energy 0, `shadow_enabled = false`,
  `sky_mode = SKY_MODE_LIGHT_ONLY`, `light_volumetric_fog_energy = 2` so the mist glows).
  `flash()` = tween 0→60 % (0.03 s) → 0.3 (0.07 s) → random gap 0.04–0.12 s → 100 % (0.03 s) →
  0 over 0.6 s `TRANS_EXPO`/`EASE_OUT`. Random interval `flash_interval` (4–11 s).

## Gotchas hit while testing (each one cost a render)
- `BaseMaterial3D.BILLBOARD_FIXED_Y` on the rain material **forces streaks vertical**; use the
  particle node's `transform_align` instead (above).
- Fragment built-ins (`INV_PROJECTION_MATRIX`, `SCREEN_UV`…) are **not visible inside helper
  functions** → "Unknown identifier". Pass them in as parameters.
- Height-based crest foam (`offset.y / amp_sum`) paints huge blobs on long swells; the Jacobian
  gives localized whitecaps. Debug masks with `EMISSION = vec3(step(t, v_crest), 0, 0)`,
  `ALBEDO = vec3(0)` and render — lit albedo hides small differences at night.
- Unlit fog only darkens: give it light (`volumetric_fog_ambient_inject`, flash light fog energy).
- `PlaneMesh` needs vertices: 240 m at `subdivide_width/depth = 240` ≈ 1 m grid (58k verts).
- In `extends SceneTree` test scripts, nodes added in `_initialize()` are not inside the tree
  yet (`global_position` errors spam) — run checks from the first `_process`.

## Verify after changes
`tools/capture.sh <storm preset>` + art-director for looks; for buoyancy logic expose
`ocean.get_height()` results in `get_telemetry()` and assert with playtester.
Next upgrades (untested): noise texture to break up foam, foam persistence, more waves via
a `uniform int wave_count`.
