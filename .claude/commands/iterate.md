---
description: Gameplay Evolution cycle - playtest evidence, game-director two-pass review, build, F1-F4 sandbox, verify, log, commit.
argument-hint: [playtest notes or focus area]
---

Run one **Gameplay Evolution iteration** on Gale Point for: $ARGUMENTS

Follow every step in order. CLAUDE.md rules (static typing, pure-code scenes, `@export` tunables,
shaders in `.gdshader`, hook must stay green, tests follow rules) apply throughout.

1. **Evidence + direction**
   - `bash tools/evidence.sh`: the newest P / F12 screenshots, the digest of the newest human play
     session (`SessionLog`: timeline, P bookmarks, hit ratio, unused tools, frame rate, errors) and recent
     rendered frames. Read the newest screenshot if it is relevant to $ARGUMENTS. If the evidence is older
     than the last commit, say so in one line: nobody has played the current build yet.
   - Read `DESIGN_LOG.md` (Learned Principles and Rejected Clichés are binding).
   - Consult the **game-director** agent with $ARGUMENTS and the evidence block pasted verbatim (it has no
     shell). It runs its Two-Pass Review (cold eyes before SPEC, then the 3-axis divergence) and returns
     a <=25-line build + sim guard note. Choose the cohesive subset to build; say in one line what you
     dropped and why.

2. **Implement** in small steps: statically typed GDScript / `.gdshader`, every tunable an
   `@export` with a sensible default, new systems as `class_name` scripts under `res://src/`.
   New assets only via the asset-fetcher agent. Add a `--shot` preset in `ShotPresets` for each new
   visual feature and expose new state in `main.get_telemetry()` (add it to `SessionLog.summary_paths`
   when a human session should report it). Unsure of a Godot 4.7 API? If the editor is connected,
   `api_manage(op="get_class")` answers from the real engine; otherwise write it and let the hook judge.

3. **Performance guard:** besides the MoodRig sun, only the lighthouse beam and active flares may use
   `shadow_enabled = true`. Every new secondary light (lanterns, buoys, braziers, embers, fires) uses
   `shadow_enabled = false` and a modest `omni_range`, so the volumetric fog stays smooth. The only real
   frame-rate numbers are `fps_avg` / `fps_low_1s` in a human session log; a drop there after a build is
   a regression to fix, not a taste question.

4. **Live human sandbox (F1-F4)** - wired in `main.gd`, active only when no locked `--shot` preset
   is running:
   - `F1`: spawn the newly added / updated enemy or interactive object 10 m in front of the player.
   - `F2`: spawn a burning flare at the player's aim point and refill rifle + flare ammo.
   - `F3`: toggle god mode and restore full HP.
   - `F4`: advance to the next wave (or trigger a lightning strike when no waves are left).
   Keep the bindings in `InputSetup` and their behaviour in one small `class_name` helper.

5. **Verify** (scripts only; godot-ai never gates a build)
   - `bash tools/godot_check.sh` (hook) must be clean.
   - `bash tools/sim.sh --all` - every scenario in `tests/suite.txt` must PASS. A scenario that fails
     because this build changed its rule on purpose gets a new expectation in the same commit (name it in
     DESIGN_LOG); a scenario that fails for any other reason is a regression, so fix the code. Never branch
     a game rule on a debug flag (`freeze_enemies`, `no_waves`, ...) to keep an old expectation green.
     Add new plans to `tests/suite.txt` for every new rule (use the playtester agent).
   - `bash tools/capture.sh <preset>` and Read at least one rendered frame of the new feature
     (the art-director agent for anything look-critical; max 3 fix rounds).

6. **Close out**
   - Update `DESIGN_LOG.md`: Learned Principles (only new, durable ones), Rejected Clichés,
     Shipped Changes (this iteration, with numbers), Next Horizon. Update SPEC.md where rules changed.
   - `git commit` with a clear message (do not stage unrelated pre-existing changes), then
     `git push origin main` so the other machine can pull it.
   - STOP and reply with a short summary and a **"15-Second In-Game Test Recipe (F1-F4)"**: 4-6
     numbered steps a human can do right after launching the game. Remind them to press P on anything
     that feels off: the screenshot and the session log are what the next `/iterate` starts from.
