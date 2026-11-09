---
name: moody-lighting
description: ALWAYS use when creating or tuning the WorldEnvironment, Environment, sky, tonemapping (AgX), exposure, glow/bloom, fog or volumetric fog, ambient light, SSAO, the sun/moon DirectionalLight3D, the lighthouse beam / SpotLight3D, light colors, or when fixing art-director feedback about mood, contrast, color or readability in this Godot 4.7 project. Gives exact render-tested starting values, the warm-vs-cold rule and the never-list.
---

# Moody storm lighting (Godot 4.7, Forward+)

Values below were rendered with `tools/capture.sh` on 4.7.2 and every property name was checked
against docs.godotengine.org/en/4.7 and the engine's `--doctool` dump. They are **starting
values**: tune through the `@export`s of `MoodRig`, then let art-director judge.

## Install
Copy `templates/mood_rig.gd` (this skill) → `res://src/world/mood_rig.gd` (`class_name MoodRig`,
Node3D). It builds WorldEnvironment + sun + beam in `_ready()`; exposes `env`, `sun`, `beam`.

## Starting values
| Area | Property | Value | Why |
|---|---|---|---|
| Tonemap | `tonemap_mode` | `TONE_MAPPER_AGX` | filmic, desaturates hot highlights instead of clipping to neon |
| | `tonemap_exposure` | 1.1 | night scene stays readable |
| | `tonemap_agx_white` | 10.0 (default 16.29) | AgX ignores `tonemap_white`; lower = highlights reach white sooner |
| | `tonemap_agx_contrast` | 1.3 (default 1.25) | slightly deeper blacks |
| Glow | `glow_enabled` / `glow_hdr_threshold` | true / 1.2 | only true HDR (beam core, lightning) blooms |
| | `glow_intensity` / `glow_bloom` | 0.5 / 0.0 | bloom > 0 makes everything glow — forbidden |
| | `glow_blend_mode` | `GLOW_BLEND_MODE_SOFTLIGHT` (default) | |
| Vol. fog | `volumetric_fog_enabled` | true | Forward+ only |
| | `volumetric_fog_density` | 0.012 | exponential; 0.03+ swallows the horizon |
| | `volumetric_fog_albedo` | `Color(0.55, 0.60, 0.65)` | cold grey-blue |
| | `volumetric_fog_anisotropy` | 0.6 | forward scatter → beams read toward camera |
| | `volumetric_fog_length` | 120.0 | |
| | `volumetric_fog_ambient_inject` | 0.8 | without it fog only darkens (tested: frame went black) |
| | `volumetric_fog_sky_affect` | 0.25 | keep sky gradient visible |
| Ambient | `ambient_light_source` | `AMBIENT_SOURCE_COLOR` | |
| | `ambient_light_color` / `_energy` | `Color(0.16, 0.20, 0.26)` / 0.8 | tinted cold fill, never neutral grey |
| SSAO | `ssao_enabled` | true | |
| | `ssao_radius` / `_intensity` / `_power` | 1.5 / 2.5 / 1.8 | grounds rocks in water |
| | `ssao_light_affect` | 0.1 | slight AO in lit areas |
| Sky | `ProceduralSkyMaterial` top / horizon | `(0.10,0.12,0.15)` / `(0.28,0.31,0.35)` | `sky_energy_multiplier` 0.7; ground_bottom `(0.05,0.06,0.07)` |
| Sun | `DirectionalLight3D.rotation_degrees` | `(-14, -35, 0)` | low grazing storm light |
| | `light_color` / `light_energy` | `Color(0.70, 0.78, 0.92)` / 0.7 | COLD key |
| | `light_volumetric_fog_energy` | 0.5 | |
| | `shadow_enabled` / `directional_shadow_max_distance` | true / 120 | |

## The beam (SpotLight3D + volumetric fog)
```gdscript
beam.light_color = Color(1.0, 0.76, 0.45)      # warm ~2700 K: the ONE warm accent
beam.light_energy = 30.0
beam.light_volumetric_fog_energy = 150.0       # docs: 200-5000 for shafts at low fog density
beam.spot_angle = 6.0                          # degrees, half-angle
beam.spot_range = 150.0                        # must reach: at -6° pitch from 16 m it missed the water
beam.spot_attenuation = 0.4                    # 0 = constant along range, 2 = inverse-square (docs)
beam.spot_angle_attenuation = 2.0              # soft cone edge
beam.shadow_enabled = true                     # occluders cut the shaft in the fog
```
Tested: fog energy 6 → invisible, 16 → faint smudge, 150 → clear warm shaft. Rotate with
`beam.rotate_y(deg_to_rad(beam_turn_speed_deg) * delta)` (25°/s); pitch -6…-12°.

## Warm-vs-cold rule
- Everything natural is **cold**: sun/moon, sky, ambient, fog, water, lightning `(0.80, 0.86, 1.0)`.
- Only **man-made light is warm** (beam, windows, lanterns), 2400–3000 K, and it must be the
  brightest thing in frame. One warm source family per shot; warm never fills a whole frame.
- Value hierarchy: beam core > lightning > foam/rain highlights > water > sky > rocks.

## Never-list
- No neon or saturated hues: no pure RGB, no saturation > ~0.6 except the beam core. No `adjustment_saturation` > 1.
- No glowing outlines/rim shaders, no emissive edges, no `glow_bloom` > 0, no glow threshold < 1.0.
- No neutral-grey ambient, no pure-black shadows (ambient energy ≥ 0.5), no crushed horizon.
- No warm sun at noon, no blue-sky day palette, no lens flares, no chromatic aberration.
- Don't fix darkness with exposure > 1.5 — add light (ambient inject, fill, beam) instead.

## Quirks (hit while building this project's harness)
- Volumetric fog works only in Forward+; FogVolume density **adds** to env density (negative subtracts).
- `tonemap_white` does nothing with AgX — use `tonemap_agx_white`.
- Unlit volumetric fog = black haze. Raise `volumetric_fog_ambient_inject` or light it.
- `Light3D.light_volumetric_fog_energy = 0` removes a light from fog (cheap); flashes still want ~2.
- Lights pointing the wrong way: Godot lights shine along local **-Z**; with `rotation_degrees`
  yaw θ the direction is `(-sin θ, ·, -cos θ)`. Check the frame, don't trust the math.
- Headless runs use a dummy renderer: lighting can only be judged via `tools/capture.sh`.
- Tune by sweep, not by guess: `tools/sweep.sh <preset> MoodRig.vfog_density 0.004 0.0085 0.017` renders
  the values side by side in one image; write the winner into the `@export` default afterwards.
- Shader built-ins (`INV_PROJECTION_MATRIX`, `SCREEN_UV`…) are not visible in helper functions — pass them in.
- Judge at night with real frames, then confirm with art-director; ≤ 3 fix rounds per milestone.
