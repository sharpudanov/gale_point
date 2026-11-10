# Gale Point: Night Watch — Specification

> Source of truth for design decisions. Code follows this file; change this file first.
> Status: **M1 done** (island, sea, storm, walk). **M2 done** (weapons, light, resupply). **M3 done** (the Drowned; leftovers in §14). **M4 done** (waves, escalation, dawn, audio mix; final notes in §14). All numbers are starting values: tune them through
> the listed `@export`s, then update this file when a value changes for good.

---

## 1. Pitch
A first-person survival shooter on a lighthouse island in a storm. You are alone from midnight until
dawn (~5 min). The Drowned crawl out of the sea and glide toward the lighthouse, and they can only
be hurt while they stand in light. You make that light yourself (three flares), borrow it from the
sweeping lighthouse beam far out at sea, or catch it for a few frames when lightning hits. A slow
bolt-action rifle does the rest. The fun is the tension between darkness (they are fast and
invisible) and the light you have to spend. The storm keeps getting worse until it breaks at dawn.

### Design brief (verbatim from the user)
```
I'm alone on a lighthouse island in a storm until dawn (~5 min). The Drowned crawl out of the sea
and glide toward the lighthouse. They can only be hurt while standing in light.
- First person, WASD + mouse look, sprint, no jumping needed. Small walkable island (noise
  heightmap + Poly Haven rock) with the lighthouse at the centre.
- Bolt-action rifle: 5 rounds, slow bolt cycle and reload, heavy recoil/sway, loud shot, built
  from primitives as a weathered viewmodel.
- Flare gun: 3 flares. A flare burns ~20s as a warm shadow-casting light that shows in the fog.
  Enemies inside light take damage and slow down; in darkness they move faster.
- Lightning: lights the whole island for a few frames and reveals every enemy.
- The Drowned: dark tattered cloaks, vertex-shader cloth, procedural glide (no walk cycle),
  pale faint features, wet footprints or water trails. Silhouettes in fog, not detail.
- Resupply: ammo crate inside the lighthouse door, refilled between waves.
- Escalation: more enemies, denser fog, bigger waves and more lightning over time. Survive to
  dawn: the storm breaks, fog lifts, cold sunrise.
- 3 hit points (lanterns or screen vignette, no cluttered HUD).
```

---

## 2. Core loop, controls, win/lose

**Loop:** a wave rises from the sea, then you light the Drowned (flare, beam, lightning) and shoot
them while they are lit. Between waves you fall back to the crate inside the lighthouse door, and
the next, bigger wave comes in a heavier storm.

### Input map (built in code by `InputSetup.ensure()`; `project.godot` is not edited)
| Action | Default | Notes |
|---|---|---|
| `move_forward/back/left/right` | W / S / A / D | |
| `sprint` | Shift | no firing while sprinting |
| `look` | mouse motion | mouse captured; 0.12°/px; +x turns right, +y looks down |
| `fire` | LMB | rifle shot / flare launch |
| `aim` | RMB (hold) | ADS: FOV 72→58 in 0.2 s, sway ×0.35 |
| `reload` | R | rifle only |
| `interact` | E | ammo crate |
| `weapon_rifle` / `weapon_flare` | 1 / 2 | switch takes 0.45 s |
| `weapon_toggle` | Q / mouse wheel | |
| `melee` | F / V | rifle-butt shove (iteration 1): works mid bolt-cycle and mid reload |
| `dev_spawn` / `dev_flare` / `dev_god` / `dev_wave` | F1 / F2 / F3 / F4 | live sandbox, normal play only (`Sandbox`, iteration 1) |
| `release_mouse` | Esc | frees the cursor (no pause menu) |
| `restart` | Enter | only on an end card |

There is no jump; Space is unbound on purpose.

### Win / lose
- **Win:** survive until `night_t ≥ night_len + dawn_len`. The phase goes `night → dawn → won`.
  The end card reads "Dawn." in a small serif at 60% opacity, fading in over 2 s. Enter restarts.
- **Lose:** HP reaches 0. The phase becomes `dead`, the screen fades to black over 1.5 s and the
  card reads "The light went out." Enter restarts. The clock freezes.

### HUD (no clutter)
- **HP** is shown only by the cold screen vignette (§4.11). There are no lanterns, because the only
  warm lights allowed are flares, muzzle flash and the lamp.
- **Ammo** is a tiny tally in the lower right, e.g. `3 | 12   ✦ 2`, in light grey (0.75, 0.77, 0.80)
  at 60% opacity. It appears after a shot, reload, switch or crate use and fades out over 2 s.
- There is no crosshair (the rifle has iron sights). A 2 px dot at 25% opacity shows from the hip only.

---

## 3. Architecture (pure code)

`main.tscn` is a bare Node3D with `main.gd`; nothing else lives in a `.tscn`. Every system is a
`class_name` script in `res://src/`. `main.gd` builds them in this order and wires references
through explicit `setup(...)` calls: no autoloads, and no `get_node` paths between systems.
(The one autoload in `project.godot`, `_mcp_game_helper`, belongs to the optional godot-ai editor addon in
`addons/godot_ai/`. It is inert without an attached editor debugger and game code never references it.)

```
Main (Node3D, main.gd)        BootArgs → DebugArgs → GameRng.seed → ShotPresets → build → get_telemetry()
├─ MoodRig        src/world/mood_rig.gd        WorldEnvironment (sky_storm sky), Sun
├─ NightClock     src/core/night_clock.gd      night_t, phase, u, dawn_progress
├─ StormDirector  src/world/storm_director.gd  pushes the escalation curves (§5.2) into everything below
├─ Ocean          src/world/ocean.gd           skill template + wave_scale
├─ Island         src/world/island.gd          StaticBody3D: heightmap mesh, HeightMapShape3D, rocks
├─ Lighthouse     src/world/lighthouse.gd      tower, gallery, lantern room, Lamp, Beam, AmmoCrate
│   └─ AmmoCrate  src/world/ammo_crate.gd
├─ StormWeather   src/world/storm_weather.gd   skill template + spray, noise mist patches, flash hooks
├─ LightField     src/combat/light_field.gd    gameplay light registry (flares, beam, lightning)
├─ WetTrails      src/world/wet_trails.gd      decal pool
├─ Enemies        Node3D container             Drowned instances (src/enemies/drowned.gd)
├─ WaveDirector   src/enemies/wave_director.gd wave table, spawning, crate restock
├─ Projectiles    Node3D container             Flare instances (src/combat/flare.gd)
├─ Player         src/player/player.gd         CharacterBody3D
│   └─ Head → PlayerCamera (src/player/player_camera.gd) → WeaponHolder (src/player/weapon_holder.gd)
│        ├─ Rifle     src/player/rifle.gd       (mesh from ViewmodelBuilder)
│        ├─ FlareGun  src/player/flare_gun.gd
│        └─ Rain (StormWeather.rain, reparented here so it follows the camera)
├─ Soundscape     src/audio/soundscape.gd      loops + pooled 3D one-shots; streams from ProcAudio
└─ PostFx         src/fx/post_fx.gd            CanvasLayer: post_film ColorRect, tally Label, end card
```

| Script | class_name | Responsibility |
|---|---|---|
| `src/boot_args.gd` | `BootArgs` | exists; reads user cmdline args |
| `src/core/input_setup.gd` | `InputSetup` | static `ensure()` adds the actions above if they are missing |
| `src/core/debug_args.gd` | `DebugArgs` | parses §7 into typed fields; shot presets fill in defaults |
| `src/core/game_rng.gd` | `GameRng` | static seeded `RandomNumberGenerator`; **all** randomness goes through it |
| `src/core/night_clock.gd` | `NightClock` | time, phase, signals `dawn_started`, `won`; freezes on `dead` |
| `src/core/shot_presets.gd` | `ShotPresets` | static `apply(main, name)`: §9 presets as bundles of debug-arg defaults plus camera pose |
| `src/world/mood_rig.gd` | `MoodRig` | moody-lighting template; the beam moves to `Lighthouse`; sky is `sky_storm.gdshader` |
| `src/world/storm_director.gd` | `StormDirector` | evaluates §5.2 each physics tick and pushes values |
| `src/world/ocean.gd` | `Ocean` | ocean-weather template; `wave_scale` multiplies steepness; `get_height()` |
| `src/world/storm_weather.gd` | `StormWeather` | ocean-weather template plus spray and mist patches; signal `lightning_struck` |
| `src/world/island.gd` | `Island` | heightmap mesh and collision, `height_at(x, z)`, rock scatter |
| `src/world/lighthouse.gd` | `Lighthouse` | tower mesh (lathe ArrayMesh with door gap), lamp, beam, `gutter()` |
| `src/world/ammo_crate.gd` | `AmmoCrate` | stock state, `use(player)` |
| `src/world/wet_trails.gd` | `WetTrails` | `stamp(pos, yaw)` from a pool of 160 Decals |
| `src/player/player.gd` | `Player` | movement, HP, invulnerability, shore block, interact |
| `src/player/player_camera.gd` | `PlayerCamera` | bob, recoil, shake, wind roll, FOV |
| `src/player/weapon_holder.gd` | `WeaponHolder` | switching, sway (breathing and mouse lag) |
| `src/player/viewmodel_builder.gd` | `ViewmodelBuilder` | static mesh builders for the rifle, flare gun, sleeve and glove |
| `src/player/rifle.gd` | `Rifle` | state machine, hitscan, muzzle flash |
| `src/player/flare_gun.gd` | `FlareGun` | ammo, reload, launches `Flare` |
| `src/combat/flare.gd` | `Flare` | ballistic flight, bounce, burn curve, light, smoke, registers with LightField |
| `src/combat/light_field.gd` | `LightField` | `query(pos) -> {lit, dps, shootable}` |
| `src/enemies/drowned_builder.gd` | `DrownedBuilder` | cloak lathe mesh, sleeves, face, hands |
| `src/enemies/drowned.gd` | `Drowned` | emerge, glide, steering, light reaction, death, trails |
| `src/enemies/wave_director.gd` | `WaveDirector` | §4.8 table; signals `wave_started`, `wave_cleared` |
| `src/fx/post_fx.gd` | `PostFx` | post_film parameters, tally, end cards |
| `src/audio/proc_audio.gd` | `ProcAudio` | synthesizes `AudioStreamWAV` buffers at boot (§4.13) |
| `src/audio/soundscape.gd` | `Soundscape` | players and gain curves |
| `src/harness/test_shot.gd` | `TestShot` | exists; harness self-test |
| `src/harness/frame_snapper.gd` | `FrameSnapper` | harness: saves the frames listed in `--snap_frames` and quits (`tools/capture.sh`) |
| `src/harness/tunable_overrides.gd` | `TunableOverrides` | harness: `--set=Class.property=value` overrides `@export` tunables as nodes enter the tree (sweeps, experiments) |
| `src/harness/session_log.gd` | `SessionLog` | harness flight recorder for human play sessions: reads telemetry only, writes `.captures/sessions/session_<unix>.jsonl` (windowed normal play, or `--session_log`); digest via `tools/evidence.sh` |

### Conventions
- **Collision layers:** 1 world (terrain, rocks, lighthouse), 2 player, 3 enemy hitboxes (Area3D),
  4 projectiles. The rifle ray masks 1 and 3 (`collide_with_areas`). LightField occlusion rays mask
  layer 1 only and exclude the lighthouse body.
- **Determinism:** gameplay runs in `_physics_process`. Every random draw goes through `GameRng`,
  seeded with `--seed` (default 1). Visual-only `_process` code may use `GameRng` too.
- **Night-time scaling:** every schedule (wave starts, spawn intervals, lightning intervals,
  dawn_len) is multiplied by `k = night_len / 300`. Animation lengths (bolt, flash tween, burn) are
  not scaled.
- **Coordinates:** the lighthouse sits at the origin on a plateau at y = 5.0 m, with the door facing +Z.
  -Z is "north". The player spawns at (0, ground, 6) with yaw 180°, facing +Z out to sea.
  `yaw_deg` is `rotation.y` in degrees; mouse +x lowers it.

---

## 4. Systems & tunables
Numbers here are starting values; the `@export` default in code is the truth.

### 4.1 NightClock
| Export | Default |
|---|---|
| `night_len` | 300.0 s |
| `dawn_len` | 20.0 s (×k) |

- `u = clamp(night_t / night_len, 0, 1)`
- `dawn_progress d = clamp((night_t − night_len) / dawn_len, 0, 1)`
- Phase: `night` while t < night_len; `dawn` while d < 1; then `won`. `dead` overrides all of these.

### 4.2 Island
| Export | Default |
|---|---|
| `size_m` / `grid` | 128 m / 129×129 verts (1 m) |
| `plateau_height` / `plateau_radius` | 5.0 m / 10 m |
| `shore_radius` / `seabed_radius` / `seabed_depth` | 40 m / 55 m / −3.0 m |
| `noise_freq` / `noise_octaves` / `noise_amp` | 0.045 / 4 (FBM simplex) / 1.6 m, faded in over r 6–14 m |
| `coast_warp_amp` / `coast_warp_freq` | 6.0 m / 0.9 cycles per radian band |
| `shore_block_height` | 0.6 m (the player can't step onto ground below this) |
| `rock_count` / `rock_radius` / `rock_scale` | 30 / r 30–48 m / 0.8–3.5 |

- Height: `h = plateau_height·(1 − smoothstep(plateau_radius, shore_radius, r')) + seabed_depth·smoothstep(shore_radius−2, seabed_radius, r') + noise`, where `r' = r + warp(angle)`.
- Material: `wet_rock.gdshader` (§6.3). Collision: `HeightMapShape3D`. `height_at(x, z)` samples the same function.
- Rocks: Poly Haven models (§11) with convex collision. Their glTF materials get `albedo_color ×0.45` and `roughness 0.3` (wet).
- Layout rules (`LayoutCheck`, telemetry `layout`, smoke expects 0 problems): braziers, casks and the winch stand on
  ground ≥ `IslandProps.min_ground`, inside the walkable boundary (`Island.walkable_radius`: per angle, the
  last radius before the ground first drops below `shore_block_height`), outside the tower plinth, and at least
  1 m apart; buoys float over ground below sea level. `tools/capture.sh map 2` shows the layout from above.

### 4.3 Lighthouse
| Part | Spec |
|---|---|
| Tower | Lathe ArrayMesh, height 15 m, base radius 3.0, top radius 2.2, wall thickness 0.4. Door gap 1.2 × 2.2 m facing +Z. Weathered plaster albedo ×0.62, roughness 0.8. Stone plinth 1.2 m tall, r 3.3. Trimesh collision. |
| Interior | Floor disc r 2.6 at y 5.0. Dark (only the ambient that leaks in through the door). |
| Gallery | Ring at y 20.0 (5 + 15), r 3.0, railing of thin cylinders, rusty iron. |
| Lantern room | Cylinder r 1.6, h 2.5. Glass albedo (0.05, 0.06, 0.07, 0.35), roughness 0.05. Black iron cone roof. |
| Lamp glass | Emissive (1.0, 0.74, 0.46), `emission_energy_multiplier` 5.0. |
| Lamp light | OmniLight3D, colour (1.0, 0.72, 0.42), energy 2.5, range 8, fog energy 2.0, at y 20.5. |
| Beam | SpotLight3D at y 20.5: colour (1.0, 0.76, 0.45), energy 30, `light_volumetric_fog_energy` 150, `spot_angle` 6°, `spot_range` 160, `spot_attenuation` 0.4, `spot_angle_attenuation` 2.0, shadows on, pitch −12°, `beam_turn_speed_deg` 25. It lights the sea band 63–150 m out (the spawn ring). |
| Gutter | When a Drowned reaches the tower: the lamp and beam energy flicker to 15% for 3 s (`gutter_time`). |

### 4.4 Player & camera
| Export | Default |
|---|---|
| `walk_speed` / `sprint_speed` / `accel` | 3.2 / 5.6 m/s / 14 m/s² |
| `eye_height` / capsule | 1.62 m / r 0.35, h 1.75 |
| `mouse_sens_deg` / pitch clamp | 0.12°/px / ±85° |
| `max_hp` / `invuln_time` | 3 / 1.5 s |
| `fov_hip` / `fov_ads` / `ads_time` | 72° / 58° / 0.2 s |
| `bob_walk` (amp, Hz) / `bob_sprint` | 0.030 m, 1.9 Hz / 0.055 m, 2.6 Hz (lateral = 0.5 × vertical) |
| `wind_roll_deg` | ±0.35° (noise, 0.4 Hz, scaled by wind / 13) |
| `hit_shake` | trauma 0.6, decaying 1.5/s; max 2.5° rotation |
| `camera near/far` | 0.03 / 600 |
| `interact_radius` | 1.8 m |

Sprinting requires sprint + forward input + on the floor. Sprinting blocks firing, ADS and reload starts.

### 4.5 Rifle (bolt action)
| Export | Default |
|---|---|
| `mag_size` / `start_reserve` / `max_reserve` | 5 / 10 / 25 |
| `range` / `damage_lit` / `damage_dark` | 150 m / 100 / 0 |
| `spread_hip` / `spread_ads` | 1.5° / 0.2° |
| `bolt_cycle_time` | 1.15 s (up 0.15, back 0.25, forward 0.25, down 0.15, settle 0.35) |
| `reload_open` / `reload_per_round` / `reload_close` | 0.45 / 0.5 / 0.45 s; firing interrupts after ≥1 round (close 0.45 s) |
| `recoil_pitch` / `recoil_yaw` | +5.5° / ±1.5°; recovers over 0.5 s to a residual of 1.0° |
| viewmodel kick | back 0.12 m, rotation x 12°, spring 18 /s, damping 0.7 |
| `sway_breath` | 0.25 Hz; 0.35° pitch / 0.2° yaw from the hip; ×0.35 in ADS |
| `sway_mouse_max` / `sway_spring` | 3.0° / 9 /s |
| muzzle flash | 0.06 s. OmniLight3D (1.0, 0.66, 0.35), energy 8, range 10, no shadow, fog energy 1.5. Two crossed quads, emissive (1.0, 0.70, 0.40) energy 12. 6-puff grey smoke. **Not** a gameplay light. |
| `rifle_state` | `ready`, `cycling`, `reloading`, `empty`, `switching` |

**Viewmodel** (`ViewmodelBuilder.rifle()`, metres, rifle-local):
- Parts:
  - Butt stock: box 0.045×0.13×0.12.
  - Wrist: box 0.04×0.07×0.30.
  - Fore-end: box 0.045×0.05×0.38.
  - Receiver: box 0.035×0.045×0.16.
  - Barrel: cylinder r 0.011, length 0.62.
  - Front sight blade: box 0.004×0.012×0.01.
  - Rear sight: box 0.03×0.01×0.02.
  - Bolt handle: cylinder r 0.006, length 0.07, with a sphere knob r 0.012.
  - Trigger guard: TorusMesh r 0.02.
  - Floorplate: box.
  - Two sling swivels; leather sling: box 0.025×0.004, slack curve.
- Stock wood: Poly Haven dark wood, albedo ×0.5, roughness 0.5.
- Metal: rusty metal, albedo (0.16, 0.16, 0.17) tint, metallic 0.9, roughness 0.38.
- Positions: hip (0.16, −0.17, −0.38); ADS (0.0, −0.105, −0.28).
- Left arm: oilskin sleeve (capsule, albedo (0.05, 0.055, 0.05), roughness 0.35) and wool glove (boxes, (0.08, 0.075, 0.07), roughness 0.9).

### 4.6 Flare gun & flares
| Export | Default |
|---|---|
| `flares_start` / `flares_max` | 3 / 3 |
| `reload_time` | 1.5 s (break-action) |
| `launch_speed` / `gravity` | 32 m/s / 9.81 m/s² |
| `bounce_damping` / `rest_speed` | 0.3 / 0.5 m/s |
| `burn_time` | 20 s: ignite 0.5 s → steady → sputter over the last 3 s |
| light | OmniLight3D colour (1.0, 0.60, 0.36), energy 7.0, range 16, attenuation 1.0, **shadows on**, `light_volumetric_fog_energy` 8.0. Flicker: noise at 9 Hz, ±18% energy, ±0.03 m position. Light 0.3 m above the flare. |
| core | Sphere r 0.06, emissive (1.0, 0.70, 0.45), energy 10 |
| smoke | GPUParticles3D, 120 particles, lifetime 6 s, rising 0.8 m/s plus wind ×0.6, grey (0.45, 0.45, 0.47) alpha 0.35, shaded (lit warm by the flare) |
| sparks | 40 particles, lifetime 0.6 s, emissive (1.0, 0.65, 0.35) energy 4 |
| sea dud | lands where `y < ocean.get_height() + 0.1` → bobs, hisses and dies over 1.5 s; `flares.drowned += 1` |

- Flare-gun viewmodel: barrel cylinder r 0.02, length 0.18; grip box; hammer.
- Paint: weathered dark olive-grey (0.18, 0.19, 0.17), roughness 0.6. **Never orange.**

### 4.7 LightField (gameplay light)
`query(pos) -> {lit: bool, dps: float, shootable: bool}`. Each source returns a contribution from
0 to 1; a point counts as lit when the sum is ≥ 0.2 and it is not occluded (one ray to the source,
layer 1).

| Source | Contribution | dps | Shootable |
|---|---|---|---|
| Flare (burning) | 1 inside `flare_radius` 13.5 m × burn factor (ignite/sputter ramps); 0 when burn factor < 0.25 | 12 | yes |
| Beam | 1 inside the 6° cone and within 160 m | 20 | yes |
| Lightning | 1 everywhere for `reveal_time` 0.6 s after a strike (no occlusion) | 0 | yes |
| Muzzle flash, lamp | not registered | 0 | no |

### 4.8 The Drowned & waves
| Export | Default |
|---|---|
| `max_hp` | 100 |
| `base_speed` / `dark_mult` / `lit_mult` | 2.4 m/s / 1.35 (=3.24) / 0.35 (=0.84) |
| `speed_response` | 4.0 /s (exponential approach to the target speed) |
| `turn_rate` / `separation` | 90°/s / 1.5 m |
| `hover_height` | 0.25 m above `max(Island.height_at, Ocean.get_height)` |
| `bob` / `lean` | 0.08 m at 0.6 Hz / 8° forward at full speed |
| `spawn_ring` | r 60–90 m in the sea, inside a seeded 70° sector per wave |
| `emerge_time` | 2.5 s (rise from 1.8 m below the surface, splash burst) |
| `aggro_radius` | 25 m. Target is the lighthouse door (0, 5, 3.2) unless the player is closer than this. |
| `contact_radius` | 1.3 m → player loses 1 HP (if not invulnerable); the Drowned dissolves |
| `tower_radius` | 3.6 m → `Lighthouse.gutter()`, player loses 1 HP; the Drowned dissolves |
| `dissolve_time` | 1.2 s (`dissolve` uniform 0→1, sink 0.6 m, puddle decal 1.4 m) |
| `trail_step` | 0.9 m (on land only) → `WetTrails.stamp()`; drips: 12 particles/s always |
| `moan_interval` | 6–14 s; first moan 0–3 s after spawning |
| lit reaction | shudder ±2 cm at 14 Hz, cloth `flutter_amp` ×1.6 |
| dark rifle hit | 0 damage, 0.25 s shudder, mist burst (20 grey particles) |
| lethal rifle hit | The frame a lit rifle hit kills (`state` → `dying`), before the 1.2 s dissolve starts: an impact burst at the hit point. (a) 40 dark water/cloth splash particles, colour (0.06, 0.07, 0.08) to (0.30, 0.33, 0.36), lifetime 0.7 s, velocity 2–5 m/s in a 60° cone away from the shooter, gravity 9.81, shaded. (b) A brief warm spark: 8 particles, lifetime 0.12 s, colour (1.0, 0.66, 0.35), emissive energy 4, plus no light node (so it never counts as gameplay light). (c) `ProcAudio` kill thud (§4.13), played 3D at the hit point; `audio.kill_thuds += 1`. Not triggered by light or lightning-only deaths. |

**Build** (`DrownedBuilder`):
- Height 2.1 m.
- Cloak: lathe ArrayMesh, 12 rings × 24 segments. Radius profile hood 0.18 → shoulders 0.42 → hem 0.55. Per-vertex hem length noise of ±0.15 m.
- Two sleeve strips: quad strips 0.12 × 0.7 m, using the cloth shader.
- Face: sphere r 0.11, scaled (1, 1.3, 0.8), recessed 0.12 m in the hood. Albedo (0.55, 0.56, 0.55), roughness 0.5. Two eye-socket spheres r 0.02, albedo (0.02, 0.02, 0.02).
- Hands: capsules r 0.03, length 0.18, albedo (0.50, 0.51, 0.50).
- Hitbox: Area3D on the Drowned root (not `_body`, which is animated every frame): capsule r 0.58, h 2.15 at y 1.05 plus a shoulder/sleeve box 1.10 x 0.75 x 0.65 at y 1.35. Casts shadows. The rifle does not rely on it alone: `Rifle._hitscan` casts a world-only ray (layer 1) for the travel distance, then tests every living Drowned with an exact ray-vs-vertical-cylinder check (centre = `global_position + _body.position + (0, 1.05, 0)`, y -0.3..+2.35, r 0.75 plus tan(1.2 deg) x range) and takes the closest one within 0.4 m of the world hit; the Area3D ray is only a fallback.
- **Emission only while "searing" (lit, so shootable).** Unlit cloth has no emission and no rim. While `lit` the cloth shader (`lit_amount`, smoothed 0..1) adds `Color(1.0, 0.55, 0.22) * 2.2` as a grazing rim plus crack veins, strongest on hood and shoulders; the cracks widen and brighten as hp drops (`damage_amount = 1 - hp/100`). The face and eye sockets get warm emission, and a steam/ash particle emitter rises from the shoulders. All of it is shading and particles: no light node, never a gameplay light.
- **Hit feedback (PostFx `Reticle`):** lit hit = 4 golden `#FFB266` X-ticks for 0.22 s (bigger on a kill); dark (immune) hit = cold slate-blue deflect ring for 0.25 s plus a dull metallic "tonk" (`Soundscape.play_deflect`). Hit/kill/dark counts: `fx.hit_markers`, `audio.deflects`.
- **Hit rule:** `Drowned.hit_shootable()` = point is lit OR the Drowned is lit OR its chest is shootable (chest height 1.35). A lit hit does 100 (one-shot kill). **Headshot (iteration 1): a ray through the hood sphere (r 0.27 at 1.9 m, x captain scale, +tan 0.35 deg x range) kills outright in any light.** **A body hit on an unlit Drowned does 50 damage (two shots kill; iteration 1, was 35/three) and shoves it back 1.4 m over 0.25 s**, with the dark-hit marker, deflect sound and a splash; light stays the big multiplier (instant kill plus burn DPS). The rule is the same under `--freeze_enemies` (debug flags stage a scenario, they never change a rule): `rifle_dark.json` checks it on a frozen target, `rifle_dark_live.json` on a gliding one. `LightField` flare occlusion rays run from 1.2 m above the queried point to 1.1 m above the flare, and `flare_radius` is 15.5 m.

**Waves** (u = t / night_len). Start times and spawn intervals scale by k.

| Wave | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| start (u) | 0.03 | 0.18 | 0.34 | 0.50 | 0.66 | 0.82 |
| count | 3 | 5 | 7 | 9 | 11 | 14 |
| spawn interval (s) | 3.0 | 2.5 | 2.0 | 1.6 | 1.3 | 1.0 |

- `max_alive` is 14 (living Drowned, emerging included; ones that are dissolving don't count); spawns wait while the cap is reached, with no catch-up burst afterwards. 49 in total.
- Each wave picks its sector centre with `GameRng` when it starts; a spawn is a uniform angle in ±35° of it and r 60–90 m.
- `--night_t` skips the waves whose start has already passed; `waves.index` counts them as played.
- A wave is *cleared* when all its spawned enemies are dead and none are pending.
- At dawn, pending spawns are cancelled and the living Drowned sink and dissolve over 3 s.

### 4.9 Ammo crate
- Box 0.8 × 0.5 × 0.6 m, Poly Haven planks (albedo ×0.55), just inside the door at (0, 5, 1.4).
- `use()`: if `stocked`, then reserve += 15 (max 25) and flares += 2 (clamped to max 3), and `stocked = false`.
- Restock: on `wave_cleared` or `wave_started`, if not stocked, set `stocked = true` and `refills += 1`.
- It starts stocked.
- There is no prompt text. The crate lid sits slightly ajar when stocked and closed when empty (diegetic).

### 4.10 StormWeather additions (beyond the skill template)
- **Spray:**
  - GPUParticles3D, ring emitter (r 36–44 m, y 0), `amount` 900 × `spray_ratio`, lifetime 1.8 s.
  - Velocity 3–7 m/s upward with 25° spread; gravity (wind × 0.8, −6, wind × 0.8).
  - Quad 0.9 m, billboard, lit. Albedo (0.78, 0.80, 0.82, 0.30), radial GradientTexture2D, `proximity_fade` 1.0 m.
  - Scale curve 0.5 → 1.6.
- **Mist:**
  - The skill's FogVolume swapped to `sea_mist.gdshader`: one 260 × 7 × 260 volume centred at y 1.5.
  - Plus 6 drifting 30 × 4 × 30 patches that move with the wind across the island and respawn upwind.
- **Lightning:**
  - Skill flash tween with a cold `DirectionalLight3D` at peak energy 6.0.
  - On a strike it also pushes the sky `flash` uniform (same curve), tweens `glow_hdr_threshold` 1.4 → 6.0 → 1.4 over the strike (so foam doesn't bloom), plays thunder, and emits `lightning_struck` (LightField reveal).
  - Intervals come from §5.2. The first strike happens no earlier than 12 s × k.

### 4.11 PostFx
`post_film.gdshader` on a full-screen ColorRect (§6.6).

| HP | `damage` |
|---|---|
| 3 | 0 |
| 2 | 0.35 |
| 1 | 0.65, plus a 1.1 Hz pulse of ±0.15 |

Each hit spikes `damage` +0.3, decaying back over 0.8 s. Death sets `fade` 0 → 1 over 1.5 s.

### 4.12 StormDirector
Every physics tick it evaluates §5.2 and pushes the values to MoodRig (environment and sun), the
sky shader, Ocean (`wave_scale`, foam threshold, roughness), StormWeather (wind, rain/spray
ratios, mist density, lightning interval), wet_rock `wetness` and Soundscape gains.

### 4.13 Audio (procedural, `ProcAudio` → `AudioStreamWAV`, 22 050 Hz mono 16-bit, synthesized at boot from `GameRng`)
| Sound | Synthesis | Playback |
|---|---|---|
| wind (12 s loop) | pink noise → one-pole lowpass sweeping 250–700 Hz, gust envelope 0.15 Hz | 2D, gain −24 dB → −10 dB with wind |
| rain (6 s loop) | white noise → highpass 2 kHz, plus random ticks at 40/s | 2D, follows rain_ratio, −30 → −14 dB |
| surf (10 s loop) | brown noise, swell envelope 0.1 Hz, lowpass 500 Hz | 4 AudioStreamPlayer3D at the shore, −18 → −6 dB with wave_scale |
| kill thud | 60 Hz → 35 Hz sine drop over 0.35 s + 120 ms lowpassed (400 Hz) noise slap + faint wet splash (bandpass noise 1.2 kHz, 80 ms); total 0.5 s | 3D at the hit point, unit size 8, −4 dB; `audio.kill_thuds += 1` |
| rifle crack | 20 ms noise burst + 90 Hz sine thump decaying 0.25 s + 1.8 s lowpassed echo tail | 2D, 0 dB; `audio.rifle_cracks += 1` |
| bolt clack / reload clicks | two 8 ms filtered clicks, 1.8 kHz / 1.2 kHz | 2D, −8 dB |
| flare launch / hiss (20 s) | thump + bandpass noise 3–6 kHz with crackle 25/s; sputter fade | 3D at the flare, unit size 6 |
| thunder | brown noise, 4 s, random rumble envelope, delay 0.3–2.0 s after the flash | 2D, −6 dB |
| moans ×4 variants | saw 90–140 Hz with a pitch glide, 5 Hz vibrato, formant bandpasses 500/1500 Hz, breath noise; 1.8–3.2 s | 3D at the enemy, unit size 10, max distance 80 m |

**Mix (M4).** Players are routed to three buses under Master, which carries a hard limiter (ceiling −1 dB):

| Bus | Carries | Level | Effects |
|---|---|---|---|
| `Ambience` | wind, rain, surf, thunder | 0 dB (+2 dB as dawn arrives, because the storm is gone) | — |
| `Weapons` | rifle crack, clicks, flare launch and hiss, kill thud | −1 dB | — |
| `Voices` | Drowned moans | −1 dB | reverb, room 0.7, damping 0.6, wet 0.18 |

- **Ducking:** a rifle crack pushes `Ambience` down −7 dB (attack 0.03 s, release 0.9 s); thunder pushes it −4 dB. Deeper wins. Exposed as `audio.duck_db`.
- Buses are looked up by name before they are added, so a scene reload (Enter) never doubles them.

Headless runs use the dummy audio driver, so tests count events (telemetry) rather than buffers.

### 4.14 Combat & weapon pass (rifle model, reticle, hitboxes, searing)
- **Rifle viewmodel is now Poly Haven's CC0 "Bolt Action Rifle 7.62"** (`res://assets/models/bolt_action_rifle_7_62/`; the requested slug `bolt_action_rifle_762` does not exist, the real one is `bolt_action_rifle_7_62`). Real scale (1.23 m). `ViewmodelBuilder.rifle()` instances the glTF, turns it so the muzzle points to -Z, puts every mesh on render layer 2, dims the albedo (`RIFLE_TINT`) and keeps the scope glass see-through. The two bolt meshes are re-parented under a `Bolt` pivot on the bore axis, so `Rifle` still animates `rotation.z` (lift) and `position.z` (draw back; `bolt_travel` 0.08). The loose cartridge mesh is removed, the scope and its mount are removed (open iron sights only), the bolt body is tucked 4.5 cm forward, and a tiny warm ivory dot sits on the front sight post. The primitive rifle and the primitive arm/hand builders are gone: no hands on the rifle.
- **ADS** looks over the open iron sights: `ads_pos = (0, -SIGHT_Y, -EYE_Z)` = eye at (0, 0.074, 0.52) in rifle space, level with the front sight tip, well behind the bolt. The rifle's kick-back is scaled to 0.2 in ADS (`kick_back_ads_scale`) and walk bob to x0.15 (`bob_ads_scale`). `PlayerCamera.near = 0.01`.
- **Reticle** (`src/fx/reticle.gd`, owned by PostFx): hip = one 2 px ivory dot at 0.28 alpha, nothing else; ADS = no 2D reticle at all (the 3D front sight tip is the mark). Hit markers (golden X-ticks / slate-blue ring) are the only other 2D feedback. Presets `ads_aim`, `ads_close`, `hit_lit`, `hit_dark`, `drowned_close`, `flare_fight` show it.
- `rifle_dark.json` / `rifle_lit.json` also expect `fx.hit_markers.dark|kill`, `audio.deflects`.

### 4.15 Iteration 1 (`/iterate`, see DESIGN_LOG.md): TTK, wound readability, shove, fire synergy, captains, bells, island props
- **TTK:** dark body hit 50 (2 shots); headshot = kill in any light; light still one-shots. Wounded (hp <= 50%) Drowned lean +10 deg, glide x0.85 and smolder: ember seams on hood/shoulders (`smolder_amount`), 6 unshaded embers, a 3D crackle loop. No UI bars.
- **Shove (F/V):** 2.7 m, 65 deg half-cone, up to 3 targets, 3.4 m knockback over 0.3 s, 0.9 s stagger (no contact damage while staggered), 20 dmg, 0.7 s cooldown, usable mid bolt-cycle/reload (`WeaponHolder`).
- **Fire rule (`FireSystem`):** flame is a physical object and a rifle round that hits flame detonates it. A flying flare that passes through a Drowned (`HitGeo` cylinder) impales it: 25 dmg, it burns (8 dps + light dps), ignores the light slowdown and lights its pack (torch GameLight r 6). A rifle round on a burning flare / oil cask / captain's lantern = burst: r 6, 60 dmg, 2 m knock, sets alight, 1.2 s glare (r 20), chains to burnables after 0.15 s. Casks also leave a 12 s oil pool (light r 9, ignites what glides through r 4).
- **LightField** now also takes `GameLight` sources (braziers, oil pools, burning Drowned, burst glare). Only the beam and active flares cast shadows; every new light has `shadow_enabled = false`.
- **Lantern Captain:** first spawn of waves 3-6 (total stays 49): 1.2x, 200 hp, x0.85 speed, Poly Haven `Lantern_01` on a hook (shootable, r 0.3); its lantern bursting does 120 to it. Drowned within 10 m of a living captain glide x1.15; when it dies they falter (x0.7 for 3 s).
- **Bell buoys:** 6 at r 55. Wave sectors are pre-picked by their own RNG (the GameRng draw is kept so other seeded events stay put); `bell_lead` 6 s (x k) before a wave the nearest buoy tolls once per wave number.
- **Island props:** 4 braziers (r ~25; lit by a resting burning flare within 2.5 m, a burst or a burning Drowned; 60 s, light r 11, 12 dps; refuelled each wave), 6 oil casks (Poly Haven `wine_barrel_01`; restocked each wave), beam winch behind the tower (hold E 1.2 s: 10 s overdrive, pitch -24, 10 deg cone, x2 dps, follows the view; 1 charge per wave).
- **Sandbox F1-F4** (`Sandbox`, not in `--shot` presets): F1 captain + wounded + fresh Drowned 10 m ahead; F2 burning flare at the aim point + full ammo; F3 god toggle + full HP; F4 next wave (bell tolls) or a lightning strike.
- **Tests:** `tools/sim.sh --all` runs `tests/suite.txt` (the 14 baselines + 12 new plans; `rifle_dark_live` now expects hp 50).

---

## 5. Visual tech spec (moody-lighting + godot-ocean-weather, adapted)

### 5.1 Palette: target on-screen colours (sRGB hex) for the art-director
| Role | Hex | Note |
|---|---|---|
| Sea body (lit by the night sky) | `#2B363D` | slate blue-grey |
| Sea troughs / deep | `#121A1F` | never pure black |
| Foam / whitecaps | `#C6CACB` | brightest cold value besides lightning |
| Sky, upper | `#2C2F36` | ash |
| Sky, bruise band | `#3A3343` | desaturated purple, saturation < 0.3 |
| Sky, horizon haze | `#4B4E56` | |
| Wet rock | `#101113`, highlights `#5C626A` | wet black, glossy highlights |
| Mist | `#8A9299` (lit) | |
| Tower plaster | `#6E7072` (night) | never brighter than the foam |
| Lamp / beam core | `#FFC27A` | warm source 1 |
| Flare core / light | `#FFB27A` / `#FF9A5C` | warm source 2 |
| Muzzle flash | `#FFA95A` | warm source 3 |
| Lightning | `#CCDBFF` | cold |
| Dawn sky / horizon | `#A7AAB4` / `#C9C8CF` | cold silver-lilac, no gold |

**Value hierarchy:** beam core / flare core > lightning > foam and rain highlights > water > sky > rock.
**Warm-vs-cold rule:** everything natural is cold. Warm (2400–3000 K) is allowed **only** for the lamp
and beam, flares and muzzle flash (the 0.12 s lethal-hit spark of §4.8 counts as muzzle-flash family:
tiny, brief, unlit). No other emissive material exists.

### 5.2 Escalation curves (StormDirector)
- `s = smoothstep(0, 1, u)` and `d = dawn_progress`.
- Each value is `lerp(lerp(calm, peak, s), dawn, d)`.
- Reported `storm.intensity = 0.15 + 0.85·s·(1 − d)`.

| Parameter (node.property) | calm (s=0) | peak (s=1) | dawn (d=1) |
|---|---|---|---|
| `Environment.volumetric_fog_density` | 0.008 | 0.026 | 0.003 |
| mist `sea_mist.density` (big volume) | 0.025 | 0.065 | 0.0 |
| mist patch density | 0.04 | 0.09 | 0.0 |
| `Environment.fog_density` (depth fog) | 0.004 | 0.012 | 0.0015 |
| `Ocean.wave_scale` (steepness ×; sum 0.58 → 0.435 / 0.754 / 0.348) | 0.75 | 1.30 | 0.60 |
| ocean `foam_threshold` (= 0.5 × steepness sum) | 0.22 | 0.38 | 0.17 |
| ocean `roughness` | 0.10 | 0.16 | 0.06 |
| wind speed (m/s; dir (0.95, 0, 0.32)) | 5 | 13 | 3 |
| rain `amount_ratio` (amount 6000, fall speed 20) | 0.45 | 1.0 | 0.0 |
| spray `amount_ratio` | 0.3 | 1.0 | 0.05 |
| lightning interval (s, ×k) | 16–26 | 4–9 | none |
| `DirectionalLight3D` sun energy | 0.75 | 0.45 | 1.6 |
| `Environment.ambient_light_energy` | 0.85 | 0.70 | 1.0 |
| `Environment.tonemap_exposure` | 1.0 | 0.9 | 0.9 |
| sky `hdri_energy` | 0.22 | 0.14 | 0.85 |
| sky `desaturate` | 0.6 | 0.65 | 0.35 |
| ocean `sky_reflect_color` | (0.24, 0.26, 0.30) | (0.20, 0.22, 0.26) | (0.55, 0.57, 0.62) |
| wet_rock `wetness` | 0.85 | 0.95 | 0.7 |

Sun at dawn: `rotation_degrees` interpolates (−14, −35, 0) → (−5, 90, 0) and `light_color`
(0.70, 0.78, 0.92) → (0.85, 0.87, 0.92). It comes from +X (east) and stays cold, with no gold.

### 5.3 Fixed environment values (MoodRig)
| Area | Property | Value |
|---|---|---|
| Background | `background_mode` / sky material | `BG_SKY` / ShaderMaterial `sky_storm.gdshader` |
| | `Sky.process_mode` / `radiance_size` | `PROCESS_MODE_REALTIME` / `RADIANCE_SIZE_256` (flash and dawn show in reflections) |
| Reflections | `reflected_light_source` | `REFLECTION_SOURCE_SKY` (HDRI reflections) |
| Tonemap | `tonemap_mode` / `tonemap_agx_white` / `tonemap_agx_contrast` | `TONE_MAPPER_AGX` / 10.0 / 1.3 |
| Glow | `glow_enabled` / `glow_hdr_threshold` / `glow_intensity` / `glow_bloom` / blend | true / 1.4 (6.0 during a flash) / 0.5 / 0.0 / `SOFTLIGHT` |
| Vol. fog | albedo / anisotropy / length / ambient_inject / sky_affect | (0.55, 0.60, 0.65) / 0.6 / 120 / 0.8 / 0.25 (dawn: albedo (0.62, 0.64, 0.68), ambient_inject 0.6) |
| Depth fog | `fog_enabled` / `fog_light_color` / `fog_aerial_perspective` / `fog_sky_affect` | true / (0.30, 0.33, 0.38) / 0.6 / 0.35. It hides the ocean edge past the 120 m volumetric length. |
| Ambient | `AMBIENT_SOURCE_COLOR`, colour | (0.16, 0.19, 0.26), dawn (0.32, 0.36, 0.42) |
| SSAO | radius / intensity / power / light_affect | 1.5 / 2.5 / 1.8 / 0.1 |
| Sun | shadows / `directional_shadow_max_distance` / fog energy | on / 120 / 0.5 |
| Lightning | colour / peak energy / fog energy / shadows / `sky_mode` | (0.80, 0.86, 1.0) / 6.0 / 2.0 / off / `SKY_MODE_LIGHT_ONLY`, rotation (−70, 140, 0) |

**Never** (from the moody-lighting skill):
- exposure > 1.5
- `glow_bloom` > 0
- glow threshold < 1.0
- `adjustment_saturation` > 1
- neutral-grey ambient
- ambient energy < 0.5
- lens flares, chromatic aberration
- rim or outline shaders
- emissive edges

---

## 6. Shaders (`res://shaders/`, loaded with `load()`)

### 6.1 `ocean.gdshader` (copied from the godot-ocean-weather template, retuned)
| Uniform | Template | Game value |
|---|---|---|
| `wave_time`, `waves[4]` | pushed | pushed by `Ocean` (steepness × `wave_scale`) |
| `deep_color` | (0.02, 0.07, 0.09) | **(0.022, 0.032, 0.040)** (slate, not teal) |
| `shallow_color` | (0.10, 0.26, 0.27) | **(0.10, 0.13, 0.15)** |
| `sky_reflect_color` | (0.32, 0.37, 0.42) | pushed (§5.2) |
| `absorption` | (0.45, 0.12, 0.09) | (0.40, 0.16, 0.12) (less cyan) |
| `fresnel_power` | 5.0 | 5.0 |
| `foam_threshold` / `foam_softness` | 0.3 / 0.15 | pushed (§5.2) / 0.15 |
| `shore_foam_width` | 0.6 | 1.2 |
| `foam_color` | (0.78, 0.80, 0.80) | (0.76, 0.78, 0.79) |
| `refraction_strength` / `roughness` | 0.04 / 0.08 | 0.04 / pushed |
| **new** `foam_noise` | — | NoiseTexture2D 512², seamless, simplex, freq 0.015 |
| **new** `foam_noise_scale` / `foam_breakup` / `foam_scroll` | — | 0.08 /m / 0.5 / wind dir × 0.02 m/s |

The plane is 400 m with 320 subdivisions (1.25 m grid), fixed at the origin.

### 6.2 `sky_storm.gdshader` (`shader_type sky`)
Equirectangular lookup: `uv = (atan(dir.x, −dir.z)/TAU + 0.5 + hdri_yaw/TAU, acos(dir.y)/PI)`.

| Uniform | Default | Purpose |
|---|---|---|
| `storm_hdri` / `dawn_hdri` | Poly Haven HDRIs (§11) | `source_color, filter_linear` |
| `hdri_energy` | 0.22 (pushed) | night darkening |
| `dawn_mix` | 0 (pushed = d) | crossfades the HDRIs |
| `tint_night` / `tint_dawn` | (0.80, 0.78, 0.92) / (0.92, 0.93, 0.98) | pushes toward ash and bruise purple / cold silver |
| `desaturate` | 0.6 (pushed) | kills any blue-sky colour in the source |
| `flash` / `flash_color` / `flash_gain` | 0 (pushed) / (0.80, 0.86, 1.0) / 2.5 | lightning lights the clouds, weighted by HDRI luminance |
| `hdri_yaw` | pushed, drifts 0.2°/s × wind/13 | slow cloud drift |
| `horizon_haze` / `horizon_haze_height` | (0.20, 0.22, 0.26) / 0.12 | softens the sky/sea seam |
| `below_horizon` | (0.03, 0.035, 0.045) | below the horizon (hidden by the sea) |

### 6.3 `wet_rock.gdshader` (spatial, triplanar; island terrain)
| Uniform | Default |
|---|---|
| `albedo_tex` / `normal_tex` / `roughness_tex` / `ao_tex` | Poly Haven dark rock (§11) |
| `triplanar_scale` / `blend_sharpness` | 0.18 /m / 4.0 |
| `darken` | 0.42 (albedo ×; wet black) |
| `wet_tint` | (0.88, 0.90, 0.95) |
| `wetness` | 0.85 (pushed) |
| `wet_roughness` | 0.22 (roughness = mix(tex, wet_roughness, wetness)) |
| `puddle_noise` / `puddle_scale` / `puddle_threshold` / `puddle_roughness` / `flat_slope` | NoiseTexture2D / 0.05 / 0.62 / 0.05 / 0.92 (normal.y) |
| `normal_strength` / `ao_strength` | 1.2 / 1.0 |

### 6.4 `drowned_cloth.gdshader` (spatial, `cull_disabled`, alpha scissor)
| Uniform | Default |
|---|---|
| `cloth_color` / `roughness` / `specular` | (0.035, 0.04, 0.045) / 0.45 / 0.6 (wet sheen) |
| `wind_dir` / `wind_strength` | pushed (normalized wind, 0–1 from speed / 13) |
| `flutter_amp` / `flutter_freq` / `flutter_wavelength` | 0.12 m / 2.3 Hz / 0.9 m |
| `drag_offset` | pushed per instance: −velocity × 0.12, so the hem trails behind |
| `hem_weight_pow` | 1.6 (weight = pow(1 − UV.y, p); hood fixed, hem moves most) |
| `tatter_tex` / `tatter_threshold` / `tatter_band` | NoiseTexture2D / 0.45 / lower 30% of the cloak |
| `dissolve` | 0 → 1 on death (noise-thresholded `ALPHA_SCISSOR`) |
| `instance uniform time_offset` | random per Drowned |

Vertex: `offset = (sin(k·y − ω·t + phase)·flutter_amp + wind·wind_strength·0.25 + drag_offset) · weight`.
No emission and no rim term while unlit; the "searing" emission (see 4.8) is driven by the `lit_amount` / `damage_amount` instance uniforms.

### 6.5 `sea_mist.gdshader` (`shader_type fog`)
| Uniform | Default |
|---|---|
| `density` | pushed (§5.2) |
| `albedo` | (0.60, 0.65, 0.70) |
| `noise_tex` / `noise_scale` / `noise_contrast` | NoiseTexture3D 64³ seamless / 0.035 /m / 1.6 |
| `wind_offset` | pushed: wind × t × 0.6 |
| `height_falloff` / `edge_fade` | 0.35 / 0.25 |

`DENSITY = density · pow(noise, noise_contrast) · exp(−height_falloff·(WORLD_POSITION.y − base_y)) · edge_mask`.

### 6.6 `post_film.gdshader` (`canvas_item`, reads `hint_screen_texture`)
| Uniform | Default |
|---|---|
| `grain_amount` / `grain_size` / `grain_shadow_bias` | 0.035 / 1.4 px / 0.6 (more grain in the shadows), animated per frame |
| `vignette_strength` / `vignette_radius` / `vignette_softness` | 0.32 / 0.78 / 0.45 |
| `saturation` | 0.92 |
| `black_lift` | (0.010, 0.012, 0.016) (cold, avoids crushed blacks) |
| `damage` | 0 (pushed): extra edge darkening ×0.55, edge desaturation 0.45, pulse |
| `fade` | 0 (pushed): to black (0.01, 0.012, 0.015) |

Other materials (rain, spray, smoke, sparks, muzzle flash, decals) are `StandardMaterial3D`.

---

## 7. Debug boot args (`DebugArgs`, after `--`; work in sim and capture)
| Arg | Effect |
|---|---|
| `--seed=N` | GameRng seed (default 1) |
| `--night_t=s` | start the clock at s seconds |
| `--night_len=s` | night length (default 300); every schedule scales by k = s/300 |
| `--no_waves` | WaveDirector spawns nothing |
| `--no_lightning` | no random strikes |
| `--flash_at=s` | one forced strike at s seconds, with a fixed 0.08 s flicker gap (peak ≈ s + 0.21); implies `--no_lightning` |
| `--spawn_at=x,z;x,z;…` | Drowned spawned already emerged, at hover height, in this order (list index = order) |
| `--freeze_enemies` | Drowned don't glide (cloth still moves) |
| `--aim` | on frame 1, the camera looks at the first Drowned's chest (1.4 m above its hover point) |
| `--place_flare=d` | a burning flare (age 3 s, smoke preprocessed) placed d m in front of the player on the ground; uses no ammo |
| `--god` | player HP never drops (contacts still consume the Drowned) |
| `--player_at=x,z` | player start (y = ground) |
| `--look=yaw,pitch` | start yaw/pitch in degrees |
| `--beam_yaw=deg` / `--beam_still` | beam start yaw / stop the rotation |
| `--fire_at=s` | the rifle fires once at s seconds (capture presets) |
| `--pre_trails` | wet smears stamped from the shore up to each `--spawn_at` point (for frozen captures, which never stamp their own) |
| `--spawn_kind=captain` / `--spawn_hp=hp` | iteration 1: the FIRST `--spawn_at` is a Lantern Captain / starts at this hp |
| `--impale_first` | a burning flare stuck in the first spawn (walking torch) |
| `--aim_part=chest\|head\|lantern` / `--aim_flare` / `--aim_cask=i` | `--aim` target: part of the first spawn / the `--place_flare` flare / oil cask i |
| `--light_braziers` / `--overdrive` / `--toll=n` | all braziers lit / beam overdrive from frame 0 / the buoy nearest the view tolls n strokes |
| `--shove_at=s` | one scripted rifle-butt shove at s seconds |
| `--set=Class.property=value` | harness, repeatable: override an `@export` tunable on every node of that `class_name` before its `_ready()`. Experiments and `tools/sweep.sh` only; never in `tests/suite.txt` or a shot preset. An unknown property is an error |
| `--snap=dir` / `--snap_frames=a,b,c` | harness (`tools/capture.sh`): save those rendered frames as `fNNNNNNNN.png`, then quit. Run with `--fixed-fps 30` |
| `--bench=s` | harness (`tools/bench.sh`): record the real frame rate for s seconds, then quit |
| `--session_log` | force the `SessionLog` recorder on in a headless sim (it then writes `sim_session.jsonl`); windowed normal play records without it |
| `--map` / `--map_plain` | harness (`MapView`): top-down orthographic tool view (top = -Z, right = +X, 10 m grid), no fog, rain, mist, beam, PostFx or viewmodel, flat white light from above; labels for props (B, C, W), buoys, rocks as dots, walkable boundary, layout problems. `--map_plain` hides props, rocks, buoys and labels (editor backdrop) |

Explicit args override preset defaults. Unknown args are ignored.

---

## 8. `get_telemetry()` keys
Nested dictionaries, JSON-safe. Vectors are `[x, y, z]` arrays rounded to 0.01; floats are rounded
to 0.001. Each key is added with its system, and a missing path reads as `null` (and fails an `--expect`).

```
physics_frames:int  shot:str  seed:int
time:      { night_t, night_len, u, dawn_progress, phase:"night|dawn|won|dead" }
storm:     { intensity, progress, wind_speed, wind:[x,z], fog_density, mist_density,
			 depth_fog_density, wave_scale, rain_ratio, spray_ratio, lightning_count:int,
			 flash_active:bool, glow_threshold, exposure }
ocean:     { wave_time, steepness_sum, height_at_origin }
player:    { pos:[x,y,z], yaw_deg, pitch_deg, speed (horizontal m/s), on_floor, sprinting,
			 hp:int, max_hp:int, alive, invuln, in_light, inside_lighthouse }
camera:    { fov, bob_offset, recoil_pitch }
weapon:    { current:"rifle|flare", ads, rifle_mag:int, rifle_reserve:int, rifle_state,
			 shots_fired:int, hits_lit:int, hits_dark:int }
flares:    { left:int, max:int, fired:int, active:int, drowned:int }
enemies:   { alive:int, spawned:int, killed:int, killed_by_rifle:int, killed_by_light:int,
			 lit_count:int, revealed_count:int, mean_speed_lit, mean_speed_dark, nearest_dist,
			 reached_lighthouse:int,
			 list:[ {id:int, pos:[x,y,z], hp, lit:bool, speed, state:"emerging|gliding|dying"} ]  (≤16, by id) }
waves:     { index:int (0 before wave 1), total:int, state:"waiting|spawning|active|cleared|over", next_wave_t,
			 pending:int (spawns still queued), peak_alive:int (most living Drowned at once) }
crate:     { stocked:bool, uses:int, refills:int }
lighthouse:{ lamp_on:bool, guttering:bool, beam_yaw }
fx:        { vignette, damage_vignette, grain }
audio:     { wind_gain, rain_gain, surf_gain, rifle_cracks:int, kill_thuds:int, flare_hiss_active:bool, moans_played:int,
			 thunders:int, duck_db (current ambience duck, <= 0), buses:int }
layout:    { problems:[str], problem_count:int }                             (LayoutCheck, see §4.2)
session:   { active:bool, lines:int, changes:int, marks:int, errors:int }   (only while SessionLog runs)
overrides: { requested:int, applied:int }                                   (only with --set)
```
- `flash_active`: the lightning reveal window (0.6 s after a strike) is open.
- `revealed_count`: Drowned lit by lightning right now.
- `mean_speed_*`: averages over gliding Drowned that are lit or dark (0 if none).

---

## 9. Shot presets (`tools/capture.sh <preset>`)
- Every preset is deterministic (seed 1), uses the player camera and leaves the game running.
- Default capture: 60 frames at 30 fps. The art-director judges the **mid frame (frame 30 = t 1.0 s)** and the last frame.
- Each preset is a bundle of §7 defaults.

| Preset | Args bundle | What to judge |
|---|---|---|
| `test` | harness self-test (unchanged) | render pipeline |
| `calm` | `--night_t=15 --no_waves --no_lightning --player_at=0,7 --look=180,-4 --beam_yaw=150` (the beam sweeps through view centre at t≈1 s) | slate sea, crest foam, Fresnel, HDRI ash/bruise sky, warm beam shaft in fog, wet black rock, grain/vignette |
| `storm_peak` | `--night_t=270 --no_waves --no_lightning --player_at=12,14 --look=225,-6 --spawn_at=30,45;40,40;22,55` | big waves and whitecaps, dense low noisy mist, angled rain, spray, silhouettes in fog; values not crushed |
| `lightning` | `--night_t=200 --no_waves --flash_at=0.80 --player_at=0,7 --look=180,-3 --freeze_enemies --spawn_at=-8,32;-3,38;4,30;10,42;15,36` | cold whole-scene flash at frame 30, every Drowned revealed as a silhouette, no bloom on foam, sky clouds lit |
| `flare_fight` | `--night_t=150 --no_waves --no_lightning --player_at=0,7 --look=180,-5 --place_flare=14 --spawn_at=-3,23;4,19;-13,28;11,30 --aim --fire_at=0.98` | warm flare vs. cold scene, flare glow in fog, flare shadows, two lit and two dark Drowned, muzzle flash on frame 30, weathered viewmodel and sway |
| `dawn` | `--night_t=320 --no_waves --player_at=-6,-10 --look=270,2` | cold sunrise from +X, fog lifted, calmer sea, no rain, nothing warm except the lamp |
| `dawn_sink` | `--night_t=309 --no_lightning --player_at=0,7 --look=180,-2 --freeze_enemies --spawn_at=-3,16;4,20;-8,26;9,30` | the living Drowned sink and dissolve over 3 s as the storm breaks (mid frame about 1/3 sunk, last frame about 2/3) |
| `dawn_card` | `--night_t=319 --no_waves --player_at=-6,-10 --look=270,2`, captured with **120 frames** (the clock hits `won` at 1 s, the card is full at 3 s) | the "Dawn." card: small serif, about 60% opacity, centred, over the cold sunrise; nothing else on screen |
| `wounded_dark` `captain` `torch` `flare_burst` `brazier` `bells` `overdrive` `shove` | iteration 1, see `ShotPresets` | wound smolder in the dark, Lantern Captain silhouette + lantern, walking torch lighting its pack, flare burst, lit brazier + cask, tolling buoy, beam overdrive, rifle-butt shove |
| `map` | `--night_t=15 --no_waves --no_lightning --map`; capture with 2 frames | tool view, not art: labels readable and on their props, boundary on the shore, `layout problems: 0` |
| `drowned_close` | `--night_t=120 --no_waves --no_lightning --player_at=0,7 --look=180,-2 --freeze_enemies --pre_trails --place_flare=18 --spawn_at=0.5,11;-3,16` | cloth flutter, tattered hem, faint pale face, silhouette against the flare glow, wet trail, drips |

---

## 10. Sim plans (`tests/plans/<name>.json`, run with `tools/sim.sh`)
- Each plan is created in the milestone that first uses it.
- 60 frames = 1 s. Player start (0, ground, 6), yaw 180°.
- Base command: `tools/sim.sh --plan=res://tests/plans/<name>.json --frames=N <debug args> --expect=...`
- The plans themselves are `tests/plans/*.json`; their arguments and expectations are the lines of
  `tests/suite.txt`. Those two are the source: don't copy them here.

---

## 11. Asset list (asset-fetcher only; Poly Haven CC0)
Fetched assets, their slugs and licences are listed in `ASSETS.md`.

---

## 12. Milestones
M1-M4 are built. Their build and acceptance lists are archived in `docs/SPEC_HISTORY.md`; later work
is logged in `DESIGN_LOG.md`.

---

## 13. ART DIRECTION
Grounded painterly realism, a moody film still, not a game demo. References: Turner storm
seascapes, "The Lighthouse" (Eggers), Dunkirk sea scenes, Faroe Islands at dusk.
Palette: slate blue-grey sea, ash and bruise-purple sky, wet black rock, white foam. The ONLY
warm colours are flares, muzzle flash and the lighthouse lamp, plus fire the player has set from them
(braziers, oil pools, bursts, burning Drowned) and the faint ember seams of a wounded Drowned (iteration 1).
Must: Poly Haven stormy HDRI for sky + reflections; Gerstner ocean shader with crest foam,
Fresnel, depth absorption; volumetric fog + low noisy FogVolumes; AgX, low exposure, glow only
on flares and lamp; angled rain, sea spray, whole-scene lightning flashes; gun sway, camera bob,
slight grain and vignette.
Audio: procedural wind, rain, surf, rifle crack, flare hiss, enemy moans.
Never: neon, cyan/magenta, saturated colour, glowing outlines, sci-fi emissives, toy low-poly,
flat lighting, cluttered HUD.

---

## 14. Open issues
Open items only. Delete an item when it is fixed; history is in `docs/SPEC_HISTORY.md`.

### World and light
- Horizon: a thin, darker seam separates sky and sea in every preset. Ideas: fade the sea far field
  into the fog colour, `fog_sky_affect` 0.7.
- `calm`: the beam's sea hotspot has a hard horizontal edge at the horizon; it could get a distance falloff.
- Dawn and the lightning flash read as flat grey. Ideas: a vertical sky gradient at dawn; a raking
  flash light (rotation -35 deg, shadows on), sky `flash` x0.6.
- Rocks: the left foreground rock in `calm` / `storm_peak` is near black, while the right-hand wet rock
  has a silvery specular that rivals foam and the flare. A fix touches every preset.
- `storm_peak`: crest foam is sparse at mid range under the peak mist.
- Wet trails are not readable in `drowned_close`. Not tried: SSR (global), a lighter `wet_color`,
  `albedo_mix` 0.6.
- Bell buoys read only marginally: a small marker lamp on a 1.6x buoy at 47 m.
- Overdrive beam core is near-clipped end-on. Flare smoke tints mauve under a burst for about 0.5 s.
  Flare haze covers about 40% of `flare_fight`.

### Drowned and viewmodel
- Close up the Drowned read as a boxy bell with slab sleeves, and as shrubs at range. Ideas: 16 rings,
  a neck and shoulder notch in `PROFILE`, tapered sleeves, hem lowered onto the rock.
- The face is a hard-edged pale crescent; it could be fainter and softer.
- At dawn the Drowned dissolve in patches, not as a smooth fade (needs a transparent cloth shader).
- The shove stock is large and slightly over-lit.

### UI
- The dawn card is a plain `Label`: no fade-out and no hint that Enter restarts.

### Tests and engine
- `full_night` does nothing, so no plan covers restocks over a whole night. A plan that walks to the
  crate between waves would.
- "ObjectDB instances leaked at exit" after long sims (static material caches in `DrownedBuilder`). Harmless.
