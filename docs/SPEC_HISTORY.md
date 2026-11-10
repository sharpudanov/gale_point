# SPEC history (archive)

Text cut from `SPEC.md` on 2026-11-10. It records how the game was built: the original sim plans,
the asset search criteria, the M1-M4 milestone lists, and the per-milestone tuning notes and
art-director leftovers. Nothing here is binding. Current rules are in `SPEC.md`, numbers in the
`@export` defaults, open issues in `SPEC.md` section 14. Don't read this file unless asked.

## From section 10: sim plans as first written


### `smoke.json` (exists, every milestone)
`--frames=120 --expect="physics_frames>=120"`

### `move.json` (M1): walk, sprint, look, no jump
```json
[
  {"f": 0,   "key": "W", "hold": 180},
  {"f": 30,  "key": "Space", "hold": 10},
  {"f": 36,  "expect": "player.on_floor==true"},
  {"f": 100, "expect": "player.speed>=3.0"},
  {"f": 100, "expect": "player.sprinting==false"},
  {"f": 120, "key": "Shift", "hold": 60},
  {"f": 170, "expect": "player.speed>=5.0"},
  {"f": 170, "expect": "player.sprinting==true"},
  {"f": 200, "to": 260, "mouse_motion": [5, 0]}
]
```
`--frames=300 --no_waves --no_lightning --expect="player.yaw_deg<=150" --expect="player.yaw_deg>=138" --expect="player.pos.2>=12" --expect="player.on_floor==true" --expect="player.hp==3" --expect="camera.fov>=71"`

### `escalation.json` (M1: storm/time keys; M4: plus waves and enemies)
```json
[
  {"f": 600,  "expect": "storm.fog_density<=0.010"},
  {"f": 600,  "expect": "storm.intensity<=0.3"},
  {"f": 600,  "expect": "storm.rain_ratio<=0.55"},
  {"f": 2700, "expect": "storm.fog_density>=0.022"},
  {"f": 2700, "expect": "storm.wave_scale>=1.15"},
  {"f": 2700, "expect": "storm.intensity>=0.8"},
  {"f": 2700, "expect": "storm.lightning_count>=2"},
  {"f": 3700, "expect": "time.phase==dawn"}
]
```
- **M1:** `--frames=3900 --night_len=60 --god --no_waves --expect="time.phase==won" --expect="storm.fog_density<=0.0035" --expect="storm.rain_ratio<=0.01" --expect="storm.wave_scale<=0.65" --expect="time.dawn_progress>=1"`
- **M4:** the same args without `--no_waves`, plus `--expect="waves.index==6" --expect="enemies.spawned>=26" --expect="enemies.alive==0" --expect="player.alive==true" --expect="waves.peak_alive<=14" --expect="fx.card==Dawn."`
  (The spawn threshold is 26, not 30: with `--night_len=60` the schedules shrink but a Drowned still needs 20–28 s to cross 60–90 m, so the 14-cap holds spawns back. The real 300 s night spawns all 49.)
- Derivation: f600 is u=0.167 (s=0.077, fog 0.0094). f2700 is u=0.75 (s=0.844, fog 0.0232, wave 1.21). Dawn runs 60–64 s.

### `rifle.json` (M2): fire, bolt gating, recoil, reload, no fire while sprinting, ADS
```json
[
  {"f": 0,   "to": 10, "mouse_motion": [0, -10]},
  {"f": 20,  "mouse_button": "left", "hold": 3},
  {"f": 24,  "expect": "weapon.shots_fired==1"},
  {"f": 24,  "expect": "weapon.rifle_mag==4"},
  {"f": 24,  "expect": "weapon.rifle_state==cycling"},
  {"f": 24,  "expect": "camera.recoil_pitch>=3.0"},
  {"f": 40,  "mouse_button": "left", "hold": 3},
  {"f": 50,  "expect": "weapon.shots_fired==1"},
  {"f": 100, "mouse_button": "left", "hold": 3},
  {"f": 104, "expect": "weapon.shots_fired==2"},
  {"f": 104, "expect": "weapon.rifle_mag==3"},
  {"f": 180, "key": "R", "hold": 3},
  {"f": 200, "expect": "weapon.rifle_state==reloading"},
  {"f": 300, "expect": "weapon.rifle_mag==5"},
  {"f": 300, "key": "W", "hold": 40},
  {"f": 300, "key": "Shift", "hold": 40},
  {"f": 320, "mouse_button": "left", "hold": 3},
  {"f": 326, "expect": "weapon.shots_fired==2"},
  {"f": 345, "mouse_button": "right", "hold": 25},
  {"f": 362, "expect": "weapon.ads==true"},
  {"f": 362, "expect": "camera.fov<=62"}
]
```
`--frames=400 --no_waves --no_lightning --expect="weapon.rifle_reserve==8" --expect="weapon.rifle_state==ready" --expect="audio.rifle_cracks==2" --expect="weapon.hits_dark==0"`
(Bolt: shot at f20 → ready at f89. Reload of 2 rounds = 1.9 s → done at f294.)

### `flare_fire.json` (M2): switch, launch, reload gating, 20 s burn
```json
[
  {"f": 0,    "to": 10, "mouse_motion": [0, 8]},
  {"f": 15,   "key": "2", "hold": 3},
  {"f": 50,   "mouse_button": "left", "hold": 3},
  {"f": 56,   "expect": "flares.fired==1"},
  {"f": 56,   "expect": "flares.left==2"},
  {"f": 56,   "expect": "weapon.current==flare"},
  {"f": 80,   "mouse_button": "left", "hold": 3},
  {"f": 90,   "expect": "flares.fired==1"},
  {"f": 150,  "expect": "flares.active==1"},
  {"f": 150,  "expect": "audio.flare_hiss_active==true"},
  {"f": 1150, "expect": "flares.active==1"}
]
```
`--frames=1450 --no_waves --no_lightning --expect="flares.active==0" --expect="flares.left==2" --expect="flares.drowned==0" --expect="audio.flare_hiss_active==false"`

### `crate.json` (M2: use; M4: restock)
```json
[
  {"f": 0,   "to": 10, "mouse_motion": [0, -10]},
  {"f": 15,  "key": "2", "hold": 3},
  {"f": 60,  "mouse_button": "left", "hold": 3},
  {"f": 66,  "expect": "flares.left==2"},
  {"f": 80,  "key": "1", "hold": 3},
  {"f": 90,  "to": 100, "mouse_motion": [0, 10]},
  {"f": 110, "key": "S", "hold": 110},
  {"f": 230, "expect": "player.inside_lighthouse==true"},
  {"f": 240, "key": "E", "hold": 3},
  {"f": 246, "expect": "crate.uses==1"},
  {"f": 246, "expect": "crate.stocked==false"},
  {"f": 246, "expect": "flares.left==3"},
  {"f": 246, "expect": "weapon.rifle_reserve==25"},
  {"f": 270, "key": "E", "hold": 3},
  {"f": 276, "expect": "crate.uses==1"}
]
```
- **M2:** `--frames=300 --no_waves --no_lightning`
- **M4:** `--frames=780 --night_len=60 --god --no_lightning --expect="crate.stocked==true" --expect="crate.refills==1"` (wave 2 starts at 10.8 s = f648 and restocks)

### `rifle_dark.json` (M3, updated): a dark body hit does 50, never a kill
```json
[
  {"f": 10, "mouse_button": "left", "hold": 3},
  {"f": 16, "expect": "weapon.hits_dark==1"},
  {"f": 16, "expect": "enemies.list.0.hp==50"},
  {"f": 16, "expect": "enemies.list.0.lit==false"}
]
```
`--frames=60 --no_waves --no_lightning --spawn_at=0,18 --freeze_enemies --aim --expect="enemies.alive==1" --expect="enemies.killed==0" --expect="weapon.hits_lit==0"`

### `rifle_lit.json` (M3): a lit hit kills
```json
[
  {"f": 20, "expect": "enemies.list.0.lit==true"},
  {"f": 30, "mouse_button": "left", "hold": 3},
  {"f": 36, "expect": "weapon.hits_lit==1"}
]
```
`--frames=120 --no_waves --no_lightning --spawn_at=0,18 --freeze_enemies --aim --place_flare=16 --expect="enemies.killed==1" --expect="enemies.killed_by_rifle==1" --expect="enemies.alive==0" --expect="flares.left==3" --expect="audio.kill_thuds==1"`

### `flare_light.json` (M3): light damages and slows, darkness speeds up
- Flare at (0, 26).
- Enemy 0 at (3, 30) is 5 m from the flare (lit) and targets the player.
- Enemy 1 at (−25, 26) stays more than 15 m from the flare on its way to the door (dark).
```json
[
  {"f": 60,  "expect": "enemies.list.0.lit==true"},
  {"f": 60,  "expect": "enemies.list.1.lit==false"},
  {"f": 60,  "expect": "enemies.lit_count==1"},
  {"f": 120, "expect": "enemies.list.0.speed<=1.0"},
  {"f": 120, "expect": "enemies.list.1.speed>=3.0"},
  {"f": 120, "expect": "enemies.mean_speed_dark>=3.0"},
  {"f": 480, "expect": "enemies.list.0.hp<=40"}
]
```
`--frames=600 --no_waves --no_lightning --god --place_flare=20 --spawn_at=3,30;-25,26 --expect="enemies.killed_by_light>=1"`
(12 dps → about 8.3 s to kill, so enemy 0 is still alive at f480 and dies around f500.)

### `beam.json` (M3): the lighthouse beam is a gameplay light far out at sea
```json
[
  {"f": 30,  "expect": "enemies.list.0.lit==true"},
  {"f": 120, "expect": "enemies.list.0.hp<=70"}
]
```
`--frames=180 --no_waves --no_lightning --freeze_enemies --beam_yaw=0 --beam_still --spawn_at=0,-90 --expect="enemies.list.0.hp<=50"`
(At 90 m the beam centre is at 20.5 − 90·tan 12° ≈ 1.4 m, with a half-width of 9.5 m.)

### `lightning.json` (M3): the flash reveals every Drowned and makes them shootable
```json
[
  {"f": 50,  "expect": "enemies.revealed_count==0"},
  {"f": 50,  "expect": "enemies.lit_count==0"},
  {"f": 66,  "expect": "storm.flash_active==true"},
  {"f": 66,  "expect": "enemies.revealed_count==2"},
  {"f": 66,  "expect": "enemies.lit_count==2"},
  {"f": 68,  "mouse_button": "left", "hold": 3},
  {"f": 74,  "expect": "weapon.hits_lit==1"},
  {"f": 150, "expect": "enemies.revealed_count==0"}
]
```
`--frames=180 --no_waves --flash_at=1.0 --spawn_at=-4,26;4,26 --freeze_enemies --aim --expect="storm.lightning_count==1" --expect="enemies.killed==1" --expect="enemies.alive==1"`

### `damage_death.json` (M3): 3 contacts → dead
```json
[
  {"f": 120, "expect": "player.hp==3"},
  {"f": 240, "expect": "player.hp==2"},
  {"f": 240, "expect": "fx.damage_vignette>=0.3"},
  {"f": 400, "expect": "player.hp==1"}
]
```
`--frames=600 --no_waves --no_lightning --spawn_at=0,16;0,24;0,32 --expect="player.hp==0" --expect="player.alive==false" --expect="time.phase==dead" --expect="audio.moans_played>=1"`
(Contacts at roughly f180, f325 and f470; 1.5 s of invulnerability doesn't overlap them.)

### `lighthouse_reach.json` (M3): reaching the tower costs HP
```json
[
  {"f": 240, "expect": "enemies.reached_lighthouse==0"}
]
```
`--frames=480 --no_waves --no_lightning --player_at=-20,-20 --spawn_at=0,20 --expect="enemies.reached_lighthouse==1" --expect="player.hp==2" --expect="lighthouse.guttering==true" --expect="enemies.alive==0"`

### `full_night.json` (M4): `[]`
`SIM_TIMEOUT=600 tools/sim.sh --plan=res://tests/plans/full_night.json --frames=19500 --every=1200 --god --expect="time.phase==won" --expect="waves.index==6" --expect="enemies.alive==0" --expect="player.alive==true" --expect="waves.peak_alive<=14" --expect="fx.card==Dawn." --expect="enemies.spawned>=40"`

## From section 11: asset search criteria

I give queries and selection criteria rather than slugs, because exact slugs aren't verified.
asset-fetcher picks the best match, and the chosen slug is recorded here and in `ASSETS.md` after fetching.

| # | Type | Res | Query | Must have | Used by |
|---|---|---|---|---|---|
| 1 | hdris | 2k | "stormy overcast dark clouds" | heavy dramatic cloud, no visible sun disk, prefer a `*_puresky` variant (no horizon buildings/trees), low saturation | `sky_storm.storm_hdri`, reflections |
| 2 | hdris | 2k | "overcast morning sunrise clouds" | low sun behind cloud, pale/cold, puresky preferred | `sky_storm.dawn_hdri` |
| 3 | textures | 2k | "dark rock cliff" | dark volcanic/coastal rock, strong normal | `wet_rock` terrain |
| 4 | textures | 2k | "white plaster wall weathered" | stains, peeling | tower |
| 5 | textures | 1k | "stone block wall" | rough stone blocks | tower plinth |
| 6 | textures | 1k | "rusty metal" | | lantern room, railing, rifle metal |
| 7 | textures | 1k | "painted metal worn" | chipped paint | flare gun, receiver |
| 8 | textures | 1k | "weathered wood planks" | | door, crate |
| 9 | textures | 1k | "dark wood" | fine grain | rifle stock |
| 10 | textures | 1k | "rough fabric" / "burlap" | normal + roughness maps (albedo ignored) | cloak detail |
| 11 | models | 1k | "rock" / "boulder" (×3 different) | coastal boulders, reasonable polycount | island scatter |
| 12 | models | 1k | "wooden crate" (optional) | | ammo crate (otherwise primitives with #8) |

Paths: `res://assets/<type>/<slug>/`.

## From section 12: milestones M1-M4

Every milestone follows the CLAUDE.md workflow:
1. Implement in small steps, keeping the hook green.
2. `tools/sim.sh --all` runs the listed plans (every new rule gets a plan and a `tests/suite.txt` line).
3. The art-director judges the listed presets, with at most 3 fix rounds; leftovers go into §14.
4. `git commit`.

"Pass" means `SIM_RESULT PASS` with 0 errors.

### M1: island, sea, storm, walk
- **Build:**
  - Fetch assets #1–#5 and #11.
  - `InputSetup`, `DebugArgs`, `GameRng`, `NightClock`, `ShotPresets`, `MoodRig` (HDRI sky shader), `Ocean`, `Island` (wet_rock), `Lighthouse` (lamp and beam, no crate yet), `StormWeather` (rain, spray, sea_mist, lightning), `StormDirector` (with dawn).
  - `Player` and `PlayerCamera` (move, sprint, look, bob, wind roll, shore block).
  - `PostFx` (grain, vignette).
  - `Soundscape` with wind, rain, surf and thunder.
- **Accept:**
  - Hook clean.
  - `smoke`, `move` and `escalation` (M1 args) pass.
  - `calm`, `storm_peak`, `lightning` and `dawn` capture without CAPTURE WARN. The art-director has no unresolved top-3 issue, or 3 rounds are done.
  - Visual checks:
	- (a) The horizon line is readable in `calm` and `storm_peak`.
	- (b) No pure-black area larger than 5% of the frame.
	- (c) Crest foam is visible in `storm_peak`.
	- (d) The warm beam shaft shows in the fog in `calm`.
	- (e) The lamp and beam are the only warm pixels.
	- (f) `dawn` has no warm/gold hue and no rain, and the fog has visibly lifted.
	- (g) Rain is visibly angled.
	- (h) The `lightning` mid frame lights the whole island, with no bloom on foam.

### M2: weapons, light, resupply
- **Build:**
  - Fetch assets #6–#9 (and #12).
  - `WeaponHolder`, `ViewmodelBuilder`, `Rifle` (states, hitscan, recoil, sway, muzzle flash), `FlareGun`, `Flare` (flight, bounce, sea dud, 20 s burn, light, smoke, sparks).
  - `LightField` (flare and beam sources; lightning hook stubbed).
  - `AmmoCrate`.
  - Ammo tally.
  - Rifle crack, bolt, flare launch and hiss audio.
- **Accept:**
  - `smoke`, `move`, `rifle`, `flare_fire` and `crate` (M2 args) pass.
  - `flare_fight` captures, with or without enemies; the Drowned are allowed to be missing until M3.
  - Visual checks:
	- (a) The flare is the warmest and brightest thing in the frame and visibly lights the fog volume.
	- (b) The flare casts shadows from rocks.
	- (c) The muzzle flash shows on the mid frame.
	- (d) The viewmodel reads as a weathered wood-and-iron rifle, not a toy (no flat colours, visible texture wear).
	- (e) Sway and bob show between the mid and last frames.

### M3: the Drowned
- **Build:**
  - Fetch asset #10.
  - `DrownedBuilder` and `drowned_cloth.gdshader`.
  - `Drowned`: emerge, glide, steering, separation, light damage and slow, faster in the dark, dark-hit shudder, dissolve.
  - LightField lightning reveal.
  - `WetTrails` and drips.
  - Moans.
  - Player damage, invulnerability, death and the death card.
  - PostFx damage vignette and fade.
  - Lighthouse gutter.
- **Accept:**
  - All earlier plans pass, plus `rifle_dark`, `rifle_lit`, `flare_light`, `beam`, `lightning`, `damage_death` and `lighthouse_reach`.
  - `flare_fight`, `lightning` and `drowned_close` pass the art-director.
  - Visual checks:
	- (a) The Drowned read as dark tattered silhouettes in the fog: shape, not detail.
	- (b) The hem visibly flutters and trails.
	- (c) The face is faint and only readable when lit.
	- (d) No emission, rim or outline on enemies, except the ember "searing" glow while an enemy stands in light (cracks + rim on hood/shoulders, warm face and eyes, steam); it must never look like a light source on the ground.
	- (e) Wet trails read on the rock in `drowned_close`.

### M4: waves, escalation, dawn
- **Build:**
  - `WaveDirector` (table, cap, cleared logic) and crate restock.
  - Full escalation curves on every target in §5.2.
  - Dawn sequence: the storm breaks, the Drowned sink, the cold sunrise, the "Dawn." card, Enter restarts.
  - Audio mix pass.
  - Budgets: ≤ 14 Drowned, ≤ 160 decals, rain 6000, spray 900.
- **Accept:**
  - Every plan passes, including `escalation` (M4 args), `crate` (M4 args) and `full_night`.
  - Every preset is captured and passes the art-director.
  - A final note in §14 lists any values that changed during tuning.

## From section 14: tuning notes and leftovers, M1 to Iteration 1

_(Filled per milestone: unresolved art-director points after 3 rounds, tuned values that differ
from this spec, chosen asset slugs.)_

### M1: chosen asset slugs (Poly Haven, CC0; also in `ASSETS.md`)
| # | Slug | Res | Used by |
|---|---|---|---|
| 1 | `overcast_soil_puresky` | 2k | `sky_storm.storm_hdri` (night) |
| 2 | `kloppenheim_01_puresky` | 2k | `sky_storm.dawn_hdri` |
| 3 | `dark_rock_02` | 2k | `wet_rock` terrain |
| 4 | `plastered_wall` | 2k | tower |
| 5 | `stone_block_wall` | 1k | plinth, interior floor |
| 11 | `boulder_01`, `rock_09`, `rock_07` | 1k | island rock scatter |

Notes: no single-rock *coastal* model exists on Poly Haven (the `coast_rocks_*` sets are 19–37 MB
clusters), so #11 uses generic rocks. Alternative night HDRI if needed: `kloofendal_overcast_puresky`.

### M1: values changed during tuning (code is authoritative; §4–§6 tables list the starting values)
| Where | Value | Spec → tuned | Why |
|---|---|---|---|
| `MoodRig.vfog_anisotropy` | vol. fog anisotropy | 0.6 → **0.25** | the player watches the beam from behind its source; forward scatter hid the shaft |
| `MoodRig.fog_sky_affect` | depth fog on sky | 0.35 → **0.5** | softer sky/sea seam |
| `StormDirector.vfog` | calm vol. fog | 0.008 → **0.0085** | slightly stronger shaft; still ≤ 0.010 at f600 (escalation) |
| `StormDirector.foam_threshold` | calm/peak/dawn | 0.22/0.38/0.17 → **0.24/0.22/0.18** | the threshold now acts on noise-modulated crest values; peak foam must read through the mist |
| `StormDirector.sun_energy` | calm/peak | 0.75/0.45 → **0.9/1.0** | storm_peak was crushed |
| `StormDirector.ambient_energy` | calm/peak | 0.85/0.70 → **1.0/1.3** | same; keeps rock above pure black |
| `StormDirector.exposure` | peak/dawn | 0.9/0.9 → **1.05/0.85** | peak readability; dawn sky not clipping |
| `StormDirector.hdri_energy` | peak | 0.14 → **0.3** | readable horizon at peak |
| `StormDirector.sky_desaturate` | dawn | 0.35 → **0.5** | kills a faint pink cast in the dawn HDRI |
| `StormDirector.sky_reflect_peak` | | (0.20,0.22,0.26) → **(0.30,0.33,0.39)** | sea body visible at peak |
| `StormDirector.ocean_roughness` | dawn | 0.06 → **0.09** | dawn sea read as flat milk |
| `ocean.gdshader` | `deep_color` | (0.022,0.032,0.040) → **(0.032,0.045,0.055)** | troughs never black |
| `ocean.gdshader` | new `lace_stretch` 0.25 + wind-stretched second foam sample | — | caps tear into wind streaks instead of solid blobs |
| `ocean.gdshader` / `Ocean.edge_fade` | waves flatten at abs(x), abs(z) from 150 to 196 m; flat 2.4 km "skirt" ring beyond the 400 m plane | — | horizon slits where the displaced plane edge met the far sea |
| `wet_rock.gdshader` | `darken` / `wet_roughness` / `puddle_roughness` | 0.42/0.22/0.05 → **0.55/0.32/0.10** | crushed blacks; rock highlights brighter than foam |
| `post_film.gdshader` | `black_lift` | (0.010,0.012,0.016) → **(0.018,0.021,0.028)** | no pure-black areas > 5% |
| `StormWeather` rain | fall speed / alpha / quad width / near fade | 20 / 0.28 / 0.015 / none → **14 / 0.16 / 0.012 / 1.5–5 m** | rain must read angled; fat near-lens streaks looked like artefacts |
| `sky_storm.gdshader` | below horizon | dark band → **horizon haze continued** | the camera far plane (600 m) exposed the below-horizon colour as a dark strip |
| `Lighthouse` plaster | `normal_scale` | 1.0 → **0.6** | 2k normals aliased into grain at range |

Implementation notes: Rain is not reparented to the camera. It is a `top_level` node that follows the
player's position, so the emitter never rotates with the view. The top metre of the tower, the gallery,
the railing and the lantern room don't cast shadows, because the beam rotates inside them (they would
cut its lower cone). Shot presets set `Player.input_locked`, so real mouse movement over the capture
window can't move the camera.

### M1: art-director leftovers after 3 rounds (all §12 checks pass; (b) is borderline)
- Horizon: a thin, slightly darker seam still separates the sky and sea in every preset. The sea far field could fade further into the fog colour.
- calm: the beam's sea hotspot (63–150 m band) has a hard horizontal edge at the horizon. This is spec'd behaviour, but it could get a distance falloff.
- dawn and the lightning flash read as fairly flat grey (no focal point). Ideas: a vertical sky gradient at dawn, dimming the dawn sea albedo by about 10%.
- The left foreground rock in calm and storm_peak is very dark (measured 0.0–1.3% pixels below 14/255). It could take a little more fill.
- storm_peak crest foam is sparse at mid range under the dense peak mist.
- Harness: on this machine `tools/capture.sh` sometimes stalls (the remaining frames are byte-identical copies). Check with `md5sum .captures/<p>/*.png | sort -u | wc -l` and re-run.
- `tools/sim.sh` prints at most 80 lines (`SIM_MAX_LINES`). With `--every=60` on long runs the SIM_RESULT line falls off; check `.captures/sim/last.log` or the exit code.


### M2: chosen asset slugs (Poly Haven, CC0; also in `ASSETS.md`)
| # | Slug | Res | Used by |
|---|---|---|---|
| 6 | `rusty_metal_02` | 1k | rifle metal, crate straps |
| 7 | `painted_metal_shutter` | 1k | flare gun paint |
| 8 | `weathered_planks` | 1k | ammo crate |
| 9 | `dark_wood` | 1k | rifle stock |
| 12 | `wooden_crate_01` (downloaded, **unused**) | 1k | no lid/ajar state, so the crate is primitives with #8 |

### M2: values changed during tuning / additions beyond the spec
| Where | Value | Spec -> tuned | Why |
|---|---|---|---|
| `Flare.bounce_friction` (new) | tangential speed kept per bounce | -> **0.35** | with 0.7 a flare thrown down at 10 deg skipped off the plateau into the sea |
| Flare hiss | loop length | 20 s -> **4 s loop** | the volume follows the burn curve/sputter, so a 20 s sample is redundant and costs boot time |
| `WeaponHolder` fill light | new | cold OmniLight3D (0.55, 0.62, 0.78), energy 1.4, range 2.5 (+ a cold SpotLight3D rim, energy 1.2), `light_cull_mask` = render layer 2 | the viewmodel crushed to black outside flare range. Viewmodel meshes are on render layer 2, so the fill lights nothing else. |
| `WeaponHolder.hip_yaw_deg` | new | **7 deg** | keeps the stock out of frame |
| Viewmodel sleeve | roughness | 0.35 -> **0.5** | 0.35 read as a gold pipe in flare light |
| Viewmodel wood | tint / roughness / tex scale | 0.5 grey / 0.5 -> **(0.30, 0.28, 0.27) / 0.62 / 1.6** | red-brown wood broke the cold-palette rule; viewmodel metal roughness 0.55, metallic 0.7 |
| Rifle muzzle flash | shape / colour / energy / light / fog energy | 2 crossed quads, (1.0,0.70,0.40), 12, light 8, 1.5 -> **spike along the barrel + 2 petals + hot core**, (1.0,0.85,0.60), 9 (core 40), light **14**, fog **3.0** | the cross read as a sprite |
| `PostFx` tally | alpha / size / margin | 0.6 / - / - -> **0.95 / 34 px, outlined / (48,40)** | unreadable over the dark stock |
| `wet_rock.gdshader` | `wet_roughness` / `puddle_roughness` / `SPECULAR` | 0.32 / 0.10 / 0.5+0.2w -> **0.50 / 0.20 / (0.3+0.1w)(1-0.5 puddle)** | moonlit specular clipped to snow-white and out-brightened the flare |
| `Lighthouse` | plinth cap ring | full ring -> **gap left open at the door** | the cap closed the doorway 1.2 m above the floor, so the player could not enter (found by `crate.json`) |
| `PlayerCamera` | recoil | `add_recoil(pitch, yaw)`; residual decays 0.5 deg/s | the residual of 1.0 deg per shot is pulled back over time |

Implementation notes: `LightField` also implements the lightning reveal (0.6 s, no occlusion), which is a small
addition to the M2 stub. The Rifle's `try_fire` while reloading with >= 1 round queues the shot until the
0.45 s close finishes. `AmmoCrate.restock()` is ready for M4's `wave_started` / `wave_cleared` wiring.

### M2: art-director leftovers after 3 rounds (flare_fight; all four sub-checks readable, none are blockers)
- Right-hand wet rock in `flare_fight` and `calm` still shows a bright silvery specular (moon/sky) that rivals foam and the flare. Next try: lower `StormDirector.sun_energy` calm value (0.9 -> ~0.6) or darken `wet_rock` highlights further. Fixing it affects every M1 preset, so it needs a re-review of `calm`/`storm_peak`.
- Rifle: still a boxy silhouette in cold light (receiver, grip). Ideas: bevelled receiver mesh, stronger rim, a cold edge on the wood.
- Left sleeve reads as a plain pillar; the glove is hidden under the fore-end at the hip pose.
- Flare shadows are only shown as dark ridges against the glow in `flare_fight` (the flare sits in a hollow). A rock closer to the flare would demonstrate (b) better.
- Sway and bob (check e) cannot be judged in `flare_fight` (recoil dominates); the breathing sway is only ~0.35 deg.
- Tally opacity was raised above the spec's 60% for legibility (0.95).


### M3: chosen asset slug (Poly Haven, CC0; also in `ASSETS.md`)
| # | Slug | Res | Used by |
|---|---|---|---|
| 10 | `hessian_230` | 1k | `drowned_cloth` detail normal + roughness (albedo unused) |

### M3: values changed during tuning / additions beyond the spec
| Where | Value | Spec -> tuned | Why |
|---|---|---|---|
| `Enemies` (new, `src/enemies/enemies.gd`) | container, spawn(), separation, kill stats, telemetry | - | the SPEC 3 "Enemies" node; M4's WaveDirector spawns through `Enemies.spawn(xz, emerged)` |
| `HitFx` (new, `src/fx/hit_fx.gd`) | lethal splash/spark, dark mist, emerge splash | - | one-shot particle bursts, no light nodes |
| `--pre_trails` (new debug arg) | | - | frozen captures never stamp wet trails |
| `Drowned.frozen_drag_speed` (new) | 0.7 | - | frozen captures still show the hem trailing |
| Cloak profile | hem radius / hem noise | 0.55 / 0.15 -> **0.64 / 0.20** | the hem read as a rigid bell; shoulders also narrowed (0.42 -> 0.36) |
| `drowned_cloth` | `flutter_amp` / `hem_weight_pow` / `tatter_threshold` / `tatter_band` / `roughness` / `specular` | 0.12 / 1.6 / 0.45 / 0.3 / 0.45 / 0.6 -> **0.2 / 1.2 / 0.6 / 0.3 / 0.75 / 0.25** | visible flutter and tatter; wet sheen made the sleeves read as pale slabs |
| Face / hands albedo | (0.55) / (0.50) -> **(0.26) / (0.28)** | the face was not faint; it read as a mask even outside the flare |
| Sleeves | shoulder x, size | 0.34 inside the cloak, 0.12 x 0.7 -> **0.44 outside the cloak, 0.09 x 0.9, hanging down** | arms were hidden inside the cloak |
| `WetTrails` | `trail_size` / `project_depth` / `wet_color` / `wet_roughness` | 0.55x1.0 / - / dark / 0.06 -> **1.3x3.0 / 2.5 / (0.06,0.07,0.09) / 0.0** | trails were invisible on near-black rock |
| `StormWeather` flash | `flash_peak_energy` / `flash_fog_energy` | 6.0 / 2.0 -> **4.5 / 0.5** | the lightning mid frame went milky grey |
| Viewmodel | left sleeve capsule radius, roughness; receiver box; wrist/floorplate | 0.045, 0.5 -> **0.032, 0.85**; receiver **0.04x0.05x0.20**; wrist y 0.055, floorplate 0.036 tall | angled forearm and no gaps between receiver, wrist, fore-end and floorplate; metal tint x2.4 -> x1.5 |
| `flare_fight` preset | 3rd Drowned | (-12,27) -> **(-13,28)** | (-12,27) was 13.4 m from the flare, inside the 13.5 m radius, so three were lit instead of two |

Implementation notes: `Player` emits `hit` on every landed hit (also in god mode) for the damage vignette, and has
`aim_at(point)` for `--aim`. PostFx runs the death fade (1.5 s) and the "The light went out." card, and Enter reloads the
scene once the card shows. `Drowned` per-instance uniforms (`time_offset`, `dissolve`, `flutter_scale`, `drag_offset`) are
`instance uniform`s on one shared `ShaderMaterial`. Tower reach and contact both call `Player.take_hit()`, so 1.5 s of
invulnerability applies to both. `lighthouse_reach` is tight: the gutter ends about 7 frames after the plan's frame-480 check.

### M3: art-director leftovers after 3 rounds (flare_fight / lightning / drowned_close; (a), (b), (d) pass, (c) marginal, (e) fails)
- **(e) Wet trails are not readable in `drowned_close`**: smears are dark on near-black rock and nothing bright sits behind them to reflect. Not tried: `Environment.ssr_enabled` (global, so it needs a re-review of every M1/M2 preset), a lighter `wet_color`, or `albedo_mix` 0.6.
- Close-up Drowned still read as a boxy bell with slab-like sleeves, and as shrubs at range (no head/shoulder notch). Ideas: more rings (12 -> 16), a neck and shoulder notch in `PROFILE`, a tapered sleeve mesh with more rows, lowering the model so the hem meets the rock.
- The face is a hard-edged pale crescent under the hood; it could be a touch fainter and softer.
- The lightning flash is still fairly flat grey. Ideas: a raking flash light (rotation -35 deg, shadows on), scaling the sky `flash` by 0.6, `fog_sky_affect` 0.7 to hide the horizon seam.
- Viewmodel: the rust texture on the receiver is blotchy at close range and the bipod/forearm tube is plain. The flare haze covers about 40% of the `flare_fight` frame (`flare light_energy` -15% would keep more slate).
- Engine: "11 ObjectDB instances leaked at exit" on shutdown after long sims (static material caches in `DrownedBuilder`). Harmless.

### M4: waves, escalation, dawn, audio mix (final notes)
Added: `WaveDirector` (`src/enemies/wave_director.gd`, §4.8), crate restock on `wave_started` / `wave_cleared`, dawn sink
(`Enemies.sink_all()` / `Drowned.dissolve_away()`), the "Dawn." card (`PostFx.on_won()`), audio buses and ducking (§4.13),
the `waves` / `audio` telemetry additions (§8) and the `dawn_sink` / `dawn_card` presets (§9). The §5.2 curves were already
complete from M1. `tests/plans/full_night.json` is `[]` on purpose.

| Where | Value | Spec -> tuned | Why |
|---|---|---|---|
| `escalation` M4 args | `enemies.spawned` | >= 30 -> **>= 26** | with `--night_len=60` the Drowned still need 20-28 s to cross 60-90 m, so the cap of 14 holds spawns back (measured 28-29). The real 300 s night spawns all 49 (peak alive 14). |
| `ViewmodelBuilder.rifle()` sling | droop / swivels / sideways bow | 0.17 -> **0.05** (as asked); swivels (y 0.034, -0.035) -> **(0.04, 0.03)**; bow 0.012 -> **0** | at 0.05 the strap still hung about 5 cm under the stock and read as a bipod leg. Leather albedo (0.11,0.075,0.05) -> (0.08,0.055,0.04), roughness 0.75 -> 0.9. |
| `drowned_cloth.gdshader` dissolve | noise | `tatter_tex` UV x (3,2) -> **x (1.1,0.7) + offset** | the fine noise made a screen-door speckle; the low-frequency noise erodes in ragged patches. This also applies to normal kills. |
| `Drowned.dawn_sink_depth` (new) | | - -> **1.9 m** | at dawn the body goes under the surface (kills keep `sink_depth` 0.6) |
| `PostFx` dawn card | font size / position | 36 -> **46**; centred -> **band 0.30-0.42 of screen height**; dark 55% shadow | grey-on-grey, and it sat on the horizon seam. The death card keeps its centred position. |
| `StormDirector.sky_desaturate` dawn | | 0.5 -> **0.65** | a faint beige/pink cast at the left horizon |
| Audio | | - | `Ambience` / `Weapons` / `Voices` buses, hard limiter -1 dB on Master, crack duck -7 dB, thunder duck -4 dB, voice reverb 0.18, +2 dB ambience at dawn |

Budgets (all hold): <= 14 living Drowned (`waves.peak_alive` is 14 in `full_night`; dissolving ones are not counted, so a few
more nodes can exist for about 1.2 s), 160 decals (`WetTrails.pool_size`), rain 6000, spray 900. `project.godot` already had
uncommitted changes before M4 (the `[rendering]` section was dropped); it is left out of the M4 commit.

M4 verification: all 14 plans pass (smoke, move, escalation M4 args, rifle, flare_fire, crate M4 args, rifle_dark, rifle_lit,
flare_light, beam, lightning, damage_death, lighthouse_reach, full_night). The art-director reviewed 8 presets; 1 fix round
plus a sling follow-up, all re-checked by eye.

### M4: leftovers
- `full_night` does nothing, so it can't show restocks over a whole night. Only `crate` (M4 args) covers a restock (`refills==1`); a plan that walks to the crate between waves would cover more.
- The dawn Drowned still dissolve unevenly (patches, not a smooth fade). A soft alpha edge would need the cloth shader to go transparent.
- The rifle strap still reads blue-grey in cold light, and the viewmodel is still boxy (see M2).
- The dawn card is a plain `Label`: no fade-out and no hint that Enter restarts (by design, no prompt text).
- Still open from earlier milestones: horizon seam, flat lightning and dawn, unreadable wet trails (M3 (e)).


- **Iteration 1 art leftovers (after 3 rounds):** the bells read only marginally, as a small fog-free marker lamp on a 1.6x buoy at 47 m. The shove stock is large and slightly over-lit. Flare smoke tints mauve under a burst for about 0.5 s. The overdrive beam core is near-clipped end-on.
