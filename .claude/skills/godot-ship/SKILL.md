---
name: godot-ship
description: Use when the user asks to export, build, package, release, publish or ship this Godot 4.7 game, to prepare a build for a playtester or a store page (itch.io, Steam), or asks what is still missing before release. Holds the one-time export setup, the headless build command, the release checklist and the store-page list. Not yet run on this project - correct this file the first time it is used.
---

# Shipping a build

Status on 2026-11-10: no export templates installed, no `export_presets.cfg`. Nothing here has been run
on this project yet; treat the commands as the documented route and fix this file after the first build.

## One-time setup (the user does this in the Godot editor, about 5 minutes)
1. Editor -> Manage Export Templates -> download the 4.7.2 templates (about 1 GB).
2. Project -> Export -> Add -> Windows Desktop. Name it `Windows Desktop`, turn on "Embed PCK", set the
   export path to `build/gale_point.exe`. Exclude `tests/*`, `tools/*`, `docs/*`, `snapshot/*`, `*.md`.
3. Commit `export_presets.cfg`. (`export_credentials.cfg` and `build/` are already gitignored.)

## Build
```bash
source tools/env.sh && mkdir -p build && "$GODOT" --headless --path . --export-release "Windows Desktop" build/gale_point.exe
```
Then run `build/gale_point.exe` once from a terminal and read its output: any `ERROR` or `SCRIPT ERROR`
line blocks the release.

## Release checklist (each "no" is an open issue in SPEC.md section 14, fixed in a polish cycle)
- [ ] The whole game can be finished: a full night to dawn, death and restart, by a human in the build.
- [ ] Shell exists: title, pause, settings, end cards, quit (godot-ui skill). Esc pauses; it never quits.
- [ ] Debug is off in a release build: F1-F4 sandbox, debug boot args and `SessionLog` only when
      `OS.is_debug_build()`. Nothing writes outside `user://`.
- [ ] No hitch the first time a weapon fires, a flare bursts or an enemy appears. If there is one, show
      each effect once behind the title card.
- [ ] Frame rate holds on the weakest target machine (`tools/bench.sh` on the laptop, heaviest preset),
      or a quality setting brings it there.
- [ ] `application/config/version` set, window title and icon set, fullscreen by default.
- [ ] Credits list every row of `ASSETS.md`; any asset that is not CC0 has its licence terms met.
- [ ] Three people who have never seen the game played the build while the user watched in silence.
      What stopped them in the first two minutes is fixed.

## Store page (itch.io first: free, instant, no review)
The user owns the account and does the upload; Claude prepares the material.
- 4 to 6 screenshots: full-resolution frames from `tools/capture.sh <preset>` (the strongest presets).
- Cover image 630 x 500, a 15 to 30 s clip of real play, three sentences of description, the controls,
  minimum specs (from `tools/bench.sh`), and the version number.
- Upload the zipped `build/` folder, or `butler push build <user>/<game>:windows` once butler is set up.
- Steam later, if at all: it needs a fee, a review, and capsule art in several sizes.

## Never
- Do not export or upload on your own initiative: both wait for the user's word.
- Do not commit a build, an export credential or a signing key.
