---
description: Gameplay Evolution cycle - playtest evidence, game-director two-pass review, build, F1-F4 sandbox, verify, log, commit.
argument-hint: [playtest notes or focus area]
---

Run one **Gameplay Evolution iteration** on Gale Point for: $ARGUMENTS

Follow every step in order. CLAUDE.md rules and gates apply throughout.

1. **Evidence + direction**
   - `bash tools/evidence.sh`: the newest P / F12 screenshots, the digest of the newest human play
     session (`SessionLog`: timeline, P bookmarks, hit ratio, unused tools, frame rate, errors), the
     contact sheet of all presets and recent frames. Read the newest screenshot if it is relevant to
     $ARGUMENTS.
   - Played? Compare the newest session with the last game change
     (`git log -1 --format=%cd -- src main.gd shaders`). If no session is newer, or it ended before the
     newest feature could appear (`waves.index` and the unused-tool counts in its `end` line), this is a
     **polish cycle**: no new mechanic or system. Build from SPEC.md section 14 or a "human test" item
     under Next Horizon. A concrete request in $ARGUMENTS still wins; say in one line that the last
     features are unplayed.
   - Read `DESIGN_LOG.md` (Learned Principles and Rejected Clichés are binding).
   - Direction. If $ARGUMENTS is a concrete request (a named fix or feature), skip the game-director and
     build exactly that. Consult the **game-director** agent only when there is playtest evidence newer
     than the last commit or $ARGUMENTS asks what to build: pass it $ARGUMENTS and the evidence block
     pasted verbatim (it has no shell). It runs its Two-Pass Review (cold eyes before SPEC, then the
     3-axis divergence) and returns a <=25-line build + sim guard note. Choose the cohesive subset to
     build; say in one line what you dropped and why.
   - Size. A cycle has to fit in one usage window and be playable in one sitting: one new mechanic, or
     up to three open issues from SPEC.md section 14. List the rest under Next Horizon in
     `DESIGN_LOG.md`.

2. **Implement** in small steps: statically typed GDScript / `.gdshader`, every tunable an
   `@export` with a sensible default, new systems as `class_name` scripts under `res://src/`.
   - `tools/api.sh <Class> [filter]` before using an engine API you are not sure of, and for an outline
     of a project class before reading it whole.
   - Anything that is a matter of degree (density, energy, colour, speed, damage): find the value with
     `tools/sweep.sh` (looks) or `tools/sim.sh ... --set=Class.property=value` (rules) first, then write the
     winner into the `@export` default. One sweep replaces several edit / capture rounds.
   - New assets only via the asset-fetcher agent. Add a `--shot` preset in `ShotPresets` for each new
     visual feature and expose new state in `main.get_telemetry()` (add it to
     `SessionLog.summary_paths` when a human session should report it).
   - Checkpoint: whenever a step leaves the gates green, `git commit` it locally (no push yet; do not
     stage unrelated pre-existing changes). If the usage limit ends the session, the next one resumes
     from `git log -5` instead of starting over.

3. **Performance guard:** besides the MoodRig sun, only the lighthouse beam and active flares may use
   `shadow_enabled = true`. Every new secondary light (lanterns, buoys, braziers, embers, fires) uses
   `shadow_enabled = false` and a modest `omni_range`, so the volumetric fog stays smooth. After adding
   lights, particles or shader work, `tools/bench.sh <the heaviest preset>`: SLOWER against the baseline
   is a regression to fix, not a taste question.

4. **Live human sandbox (F1-F4)** - wired in `main.gd`, active only when no `--shot` preset is running:
   - `F1`: spawn the newly added / updated enemy or interactive object 10 m in front of the player.
   - `F2`: spawn a burning flare at the player's aim point and refill rifle + flare ammo.
   - `F3`: toggle god mode and restore full HP.
   - `F4`: advance to the next wave (or trigger a lightning strike when no waves are left).
   Keep the bindings in `InputSetup` and their behaviour in one small `class_name` helper.

5. **Verify** (scripts only; godot-ai never gates a build)
   - Logic: `bash tools/sim.sh --all` - every scenario in `tests/suite.txt` must PASS. A scenario that
     fails because this build changed its rule on purpose gets a new expectation in the same commit (name
     it in DESIGN_LOG); a scenario that fails for any other reason is a regression, so fix the code.
     Add a plan and a suite line for every new rule.
   - Looks: `bash tools/shots.sh`. ERROR or BLANK must be fixed. For each CHANGED or NEW preset Read its
     pair image (or the contact sheet): intended changes stay, anything else is a regression. For the
     new feature itself `bash tools/capture.sh <preset>` and Read the `strip` (it shows timing and
     motion); the art-director agent for anything look-critical: one fix round by default, up to 3
     only when the user asks for a polish pass, naming the round so it compares with `pair`. Then
     `bash tools/shots.sh --accept` and a local checkpoint commit.

6. **Close out**
   - Update `DESIGN_LOG.md`: Learned Principles (only new, durable ones), Rejected Clichés,
     Shipped Changes (this iteration, with numbers), Next Horizon. Update SPEC.md where rules changed.
   - `git commit` with a clear message (do not stage unrelated pre-existing changes), then
     `git push origin main` so the other machine can pull it.
   - STOP and reply with a short summary and a **"15-Second In-Game Test Recipe (F1-F4)"**: 4-6
     numbered steps a human can do right after launching the game, features nobody has played yet
     first. Remind them to press P on anything that feels off (the screenshot and the session log are
     what the next `/iterate` starts from) and ask for one sentence on what felt worst: that sentence
     is the argument of the next `/iterate`.
