---
description: Gameplay Evolution cycle - game-director two-pass review, build, F1-F4 sandbox, verify, log, commit.
argument-hint: [playtest notes or focus area]
---

Run one **Gameplay Evolution iteration** on Gale Point for: $ARGUMENTS

Follow every step in order. CLAUDE.md rules (static typing, pure-code scenes, `@export` tunables,
shaders in `.gdshader`, hook must stay green) apply throughout.

1. **Context + direction**
   - `ls -t .captures/screenshots/ | head -3`; if the newest player screenshot (P / F12) is relevant
     to $ARGUMENTS, Read it.
   - Read `DESIGN_LOG.md` (Learned Principles and Rejected Clichés are binding).
   - Consult the **game-director** agent with $ARGUMENTS. It runs its Two-Pass Review (cold eyes
     before SPEC, then the 3-axis divergence) and returns a <=25-line build + sim guard note.
     Choose the cohesive subset to build; say in one line what you dropped and why.

2. **Implement** in small steps: statically typed GDScript / `.gdshader`, every tunable an
   `@export` with a sensible default, new systems as `class_name` scripts under `res://src/`.
   New assets only via the asset-fetcher agent. Add a `--shot` preset in `ShotPresets` for each new
   visual feature and expose new state in `main.get_telemetry()`.

3. **Performance guard:** only the lighthouse beam and active flares may use `shadow_enabled = true`.
   Every new secondary light (lanterns, buoys, braziers, embers, fires) uses `shadow_enabled = false`
   and a modest `omni_range`, so the volumetric fog stays smooth.

4. **Live human sandbox (F1-F4)** - wired in `main.gd`, active only when no locked `--shot` preset
   is running:
   - `F1`: spawn the newly added / updated enemy or interactive object 10 m in front of the player.
   - `F2`: spawn a burning flare at the player's aim point and refill rifle + flare ammo.
   - `F3`: toggle god mode and restore full HP.
   - `F4`: advance to the next wave (or trigger a lightning strike when no waves are left).
   Keep the bindings in `InputSetup` and their behaviour in one small `class_name` helper.

5. **Verify**
   - `bash tools/godot_check.sh` (hook) must be clean.
   - `bash tools/sim.sh --all` - every scenario in `tests/suite.txt` must PASS. Gate live-play-only
     changes behind `not _hub.freeze`, `waves.enabled` or a default-off flag so the baselines stay
     green; add new plans to `tests/suite.txt` for every new rule (use the playtester agent).
   - `bash tools/capture.sh <preset>` and Read at least one rendered frame of the new feature
     (the art-director agent for anything look-critical; max 3 fix rounds).

6. **Close out**
   - Update `DESIGN_LOG.md`: Learned Principles (only new, durable ones), Rejected Clichés,
     Shipped Changes (this iteration, with numbers), Next Horizon. Update SPEC.md where rules changed.
   - `git commit` with a clear message (do not stage unrelated pre-existing changes).
   - STOP and reply with a short summary and a **"15-Second In-Game Test Recipe (F1-F4)"**: 4-6
     numbered steps a human can do right after launching the game.
