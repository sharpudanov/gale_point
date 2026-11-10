---
name: game-feel
description: ALWAYS use when a playtest note, the user or the game-director says something feels weak, floaty, stiff, unresponsive, unfair, confusing or boring, when a change passes the sims but plays badly, and before adding or retuning a weapon, hit reaction, enemy attack, player damage, pickup, movement or camera motion in this Godot 4.7 project. Gives a four-question diagnosis, the feedback layers this project already has (with value ranges), the order to add them in, and how to settle feel with one sweep and one human question instead of edit / capture rounds.
---

# Game feel: diagnose first, then add the cheapest layer

Feel cannot be proven by `sim.sh`: a sim guards rules, a human judges feel. So spend tokens on one
well-aimed change and one human question, not on rounds of guessing.

## 1. Diagnose (name ONE failing question before editing)
| Question | It fails when | Typical fix |
|---|---|---|
| **Response**: did the game answer my input at once? | first feedback later than the same frame (picture) or about 50 ms (sound); a wind-up before the player's own action | fire the effect on press, move the delay into the recovery |
| **Readability**: do I know what happened and why? | damage with no visible source, an enemy attack with under 0.4 s of tell, two events that look alike | a tell (pose, sound, light) before the hit; one distinct cue per event |
| **Weight**: did it matter? | a kill and a miss feel the same; only one channel answers | layer channels (below), scaled by importance |
| **Rhythm**: is there a beat? | no pause to breathe, or dead time over about 3 s with no decision | recovery windows, cooldowns the player can feel, waves with a rest |

The newest play session shows which one: `tools/evidence.sh` (unused tools = unreadable or unrewarding;
low hit ratio = response or readability; sessions that end early = rhythm).

## 2. Layers, cheapest first (stop when the event reads)
| # | Layer | Hook in this project | Starting range |
|---|---|---|---|
| 1 | Sound, layered | `ProcAudio` / `Soundscape` | body + sharp transient + tail; pitch varied by +-5% per play |
| 2 | Camera kick | `PlayerCamera.add_recoil(pitch, yaw)` | 1 to 3 degrees, fast out, slow back |
| 3 | Camera shake | `PlayerCamera.add_trauma(x)` | 0.15 light, 0.3 firm, 0.5 heavy; never while aiming a precise shot |
| 4 | Reaction on the target | `Drowned` stagger / knock-back, `HitFx.*` | flinch within 1 frame, 0.2 to 0.4 s stagger |
| 5 | Particles and light | `HitFx`, `FireFx`, a brief unshadowed light | 6 to 20 particles, under 0.5 s |
| 6 | Screen | `PostFx`, `Reticle` | a 0.1 to 0.25 s pulse; never a permanent overlay |
| 7 | Time | local freeze (below) | 40 to 80 ms, kills and heavy hits only |

Rules:
- A common event (a shot) gets 2 or 3 layers. A rare one (a kill, a burst, taking damage) gets 4 or more.
  If everything shakes, nothing does.
- Asymmetry: the action is fast (1 to 3 frames to full effect), the recovery is slow (0.2 to 0.6 s, eased).
- Feedback never hides information: the target stays visible through the effect, and shake stays under
  `PlayerCamera.shake_max_deg`.
- It must fit SPEC.md section 13 and the Rejected Cliches in `DESIGN_LOG.md`: no hit numbers, no bars,
  no arcade markers. Readability lives on the body and in the light.
- Hit stop is local: freeze the hit enemy's motion and the viewmodel for a moment. Do not touch
  `Engine.time_scale`: it shifts every frame-counted sim expectation.

```gdscript
@export var hit_freeze_s: float = 0.06

var _freeze_left: float = 0.0

func freeze(seconds: float) -> void:
	_freeze_left = maxf(_freeze_left, seconds)

func _physics_process(delta: float) -> void:
	if _freeze_left > 0.0:
		_freeze_left -= delta
		return                      # skip movement and animation this tick; timers of the rules keep running
	_tick(delta)
```

## 3. Settle the value cheaply
- Every strength is an `@export`. Find it with ONE `tools/sweep.sh <preset> Class.property v1 v2 v3` (a
  look) or by reading the `strip` of one `tools/capture.sh <preset>` (timing: 6 frames over time).
- A new feel change comes with its F1-F4 sandbox recipe, so the human reaches it in 15 seconds.
- Then ask the human ONE question that has a one-word answer ("is the second shot too slow, too fast or
  right?"). Their answer sets the value; do not run another round without it.
- If a rule changed (a cooldown, a stagger time), update its plan's `--expect` and SPEC in the same commit.

## 4. "Passes the tests, plays badly" checklist
1. Is the first 60 seconds teaching the one core verb, with a success inside 20 seconds?
2. Does every tool have a moment where it is the best answer? (unused-tool counts in the session digest)
3. Can the player always tell why they were hurt, and what they should have done?
4. Is there a dominant strategy that skips the loop (a safe spot, a spam button)?
5. Does difficulty rise in steps the player can feel, with a rest after each?
Fix the first "no". One fix per cycle, then play.
