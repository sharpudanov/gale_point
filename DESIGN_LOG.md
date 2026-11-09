# Gale Point — Design Log

Running memory of the `/iterate` Gameplay Evolution cycles. `SPEC.md` stays the source of truth for
rules and numbers; this log records *why* we changed things and what we refuse to do.

## Learned Principles
1. **Real assets over programmer-art hero meshes.** Code builds terrain, water, shaders, lighting and
   architecture. Never use primitive boxes/cylinders for first-person weapons or fake arms when a
   real CC0 `.gltf` model fits (via the asset-fetcher agent, Poly Haven only).
2. **Clean sight picture.** Keep open iron sights clean; never draw 2D arcade crosshairs over 3D
   weapon geometry. The front post is the reticle.
3. **Bulletproof hit detection.** Always pair moving `Area3D` hitboxes with a deterministic geometric
   ray-vs-cylinder check, so animation never desyncs hitscan.
4. **TTK vs. cadence.** Match enemy health to the 5-round bolt-action cadence; always verify feel with
   human playtesting (`F1`–`F4`) rather than trusting headless JSON alone.
5. **One physical rule beats many scripted cases.** "Flame is a physical object, and a rifle round that
   hits flame detonates it" covers flares, casks and lanterns with one burst function and chains for
   free. New interactions should extend a rule (`FireSystem.BURNABLE`, `ShootableGear`, `GameLight`), not
   add a special case. *(iteration 1)*
6. **Wound state lives on the body.** Readability comes from the enemy itself (ember seams, embers,
   crackle, a limp), never from bars or numbers. Keep it under the lit "sear" in brightness so light
   stays the primary read. *(iteration 1)*
7. **Light is the economy, fire is how you invest it.** Every new warm thing must be player-made (from a
   flare, a burst or a shot cask) and must matter as gameplay light; otherwise it breaks the palette and
   the loop. *(iteration 1)*
8. **Protect seeded determinism.** New randomness uses its own `RandomNumberGenerator`; when a draw has to
   move, keep the old `GameRng` call so every other seeded event stays where it was. *(iteration 1)*

## Rejected Clichés
- **Red exploding barrels** (iteration 1). Casks are lamp oil: shooting one makes *light* (a burst and a
  burning pool), and its damage is secondary. No hazard paint, no barrel-everywhere arenas.
- **Health bars / damage numbers** (iteration 1). A wounded Drowned smolders and limps instead.
- **Hitmarker-spam melee** (iteration 1). The shove is a knock-back-and-stagger tool for the bolt-cycle
  gap, not a damage button (20 dmg, 0.7 s cooldown).

## Shipped Changes
### Iteration 1: combat feel, fire synergy, captains, bells, island agency
- **TTK:** unlit body hit 35 → **50** (2 shots kill, one bolt cycle 1.15 s between them); **headshot** through
  the hood sphere (r 0.27 at 1.9 m) kills in any light; lit hits still one-shot.
- **Wounded readability:** hp ≤ 50% → ember seams on hood/shoulders (`smolder_amount`), 6 tiny embers,
  3D ember crackle, +10° lean and ×0.85 glide speed.
- **Rifle-butt shove (F / V):** 2.7 m, 65° cone, ≤ 3 targets, 3.4 m knockback, 0.9 s stagger (no contact
  damage while staggered), 20 dmg, 0.7 s cooldown, works mid bolt-cycle and mid reload.
- **Flare impale → walking torch:** a flying flare that passes through a Drowned sticks in it (25 dmg),
  sets it burning (8 dps), cancels its light slowdown and lights its pack (r 6 GameLight + the flare's own
  15.5 m light).
- **Burst rule:** a rifle round on a burning flare, an oil cask or a captain's lantern → r 6, 60 dmg, 2 m
  knock, ignites, 1.2 s glare (r 20), chains to burnables. Casks leave a 12 s oil pool.
- **Lantern Captain** (first spawn of waves 3–6, total still 49): 1.2×, 200 hp, Poly Haven `Lantern_01` on a
  hook, shootable lantern (120 to itself + burst), +15% speed aura, packmates falter when it dies.
- **Bell buoys:** 6 iron buoys at 55 m; the one nearest the next wave's sector tolls once per wave number
  6 s (× k) before it rises. Sectors come from their own RNG.
- **Island props:** 4 signal braziers (lit by a resting flare, a burst or a burning Drowned; 60 s, r 11
  light), 6 oil casks (Poly Haven `wine_barrel_01`, restocked per wave), beam winch behind the tower (hold E
  1.2 s → 10 s overdrive: beam lowered to −24°, 10° cone, ×2 dps, follows your view; 1 charge per wave).
- **Sandbox F1–F4** for humans; `tools/sim.sh --all` + `tests/suite.txt` (26 scenarios).
- **Art-director:** 3 rounds. Round 1 failed wounded_dark (glitter), captain (lantern invisible), flare_burst
  (white-out), bells (invisible), shove (no visible knockback). After the fixes all 8 presets pass; bells is
  marginal (a small marker at 47 m in haze).
- **Leftovers:** the shove stock is large and a little over-lit by the cold viewmodel fill. Flare smoke goes
  mauve under the burst glare for about 0.5 s. The overdrive beam core is near-clipped seen end-on. Buoys
  can't move closer than about 45 m, because the coast reaches 40 m.

## Next Horizon
- **Interior gallery access:** stairs to the lantern gallery as a high, exposed firing position (needs
  interior geometry + collision; the winch already gives a reason to leave the door).
- **Second variant with a different verb** (e.g. a crawler that comes up the cliff faces, out of the beam's
  reach) once the captain is human-tested.
- **Tune with humans:** captain aura strength, brazier burn time vs. flare count, shove cooldown.
- **Fire vs. rain:** heavy rain could shorten oil-pool life at storm peak (ties the weather curve to the
  fire economy).
