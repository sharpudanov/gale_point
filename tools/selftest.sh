#!/usr/bin/env bash
# Harness self-test: injects known faults and proves that every gate catches them, and that clean input
# passes. A gate that cannot fail is not a gate.
#   tools/selftest.sh          everything (about 3 min; opens a few game windows)
#   tools/selftest.sh --fast   skips the render tests and the Stop-gate test (about 1 min)
# Exit 0 only if every check passes. Run it after changing anything in tools/, tests/sim_bot.gd, the hooks
# in .claude/settings.json or the [debug] warning settings in project.godot.
set -u
FAST=0
[ "${1:-}" = "--fast" ] && FAST=1
source "$(dirname "${BASH_SOURCE[0]}")/env.sh" || exit 3
cd "$PROJECT_ROOT" || exit 3
ensure_imported

TMP="tests/_selftest"
SUITE_BAK=".captures/_selftest_suite.bak"
pass=0
fail=0
LAST_OUT=""
ok() { printf 'PASS  %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL  %s  (%s)\n' "$1" "$2"; fail=$((fail + 1)); }
want_code() {   # <name> <wanted exit code> <command...>
  local name="$1" want="$2"
  shift 2
  LAST_OUT="$("$@" 2>&1)"
  local got=$?
  if [ "$got" -eq "$want" ]; then
    ok "$name"
  else
    no "$name" "exit $got, wanted $want: $(echo "$LAST_OUT" | tail -n 2 | tr '\n' ' ' | cut -c1-200)"
  fi
}
want_text() {   # <name> <regex that must appear in the previous command's output>
  if echo "$LAST_OUT" | grep -qE "$2"; then ok "$1"; else no "$1" "missing /$2/ in: $(echo "$LAST_OUT" | tail -n 2 | tr '\n' ' ' | cut -c1-200)"; fi
}
cleanup() {
  rm -rf "$TMP" .captures/_selftest
  [ -f "$SUITE_BAK" ] && mv -f "$SUITE_BAK" tests/suite.txt
  ensure_imported force
}
trap cleanup EXIT
rm -rf "$TMP" && mkdir -p "$TMP" .captures
check() { bash tools/godot_check.sh --file "$1"; }

echo "== parse gate (tools/godot_check.sh)"
printf 'extends RefCounted\n\n\nfunc f(a: int) -> int:\n\treturn a + 1\n' >"$TMP/ok.gd"
want_code "clean script passes" 0 check "$TMP/ok.gd"

printf 'extends RefCounted\n\n\nfunc f(:\n\tpass\n' >"$TMP/bad_syntax.gd"
want_code "syntax error is blocked" 2 check "$TMP/bad_syntax.gd"
want_text "  ... and reported as file:line" 'res://tests/_selftest/bad_syntax\.gd:[0-9]+'
rm -f "$TMP"/bad_syntax.gd*

printf 'extends RefCounted\n\n\nfunc f() -> void:\n\tvar n: Node = Node.new()\n\tn.no_such_method()\n\tn.free()\n' >"$TMP/bad_call.gd"
want_code "call to a method that does not exist is blocked" 2 check "$TMP/bad_call.gd"
rm -f "$TMP"/bad_call.gd*

printf 'extends RefCounted\n\n\nfunc f() -> int:\n\tvar x = 5\n\treturn x\n' >"$TMP/untyped.gd"
want_code "untyped declaration is blocked (typing gate)" 2 check "$TMP/untyped.gd"
rm -f "$TMP"/untyped.gd*

printf 'extends RefCounted\n\n\nfunc f(d: Dictionary) -> void:\n\tvar v: Variant = d["a"]\n\tv.explode()\n' >"$TMP/unsafe.gd"
want_code "unsafe call on a Variant is blocked (typing gate)" 2 check "$TMP/unsafe.gd"
rm -f "$TMP"/unsafe.gd*

printf 'shader_type spatial;\n\nvoid fragment() {\n\tALBEDO = vec3(1.0) + ;\n}\n' >"$TMP/bad.gdshader"
want_code "broken shader is blocked" 2 check "$TMP/bad.gdshader"
want_text "  ... and names the shader file" 'bad\.gdshader'
rm -f "$TMP"/bad.gdshader*

printf 'class_name SelftestA\nextends RefCounted\n\n\nfunc hello() -> int:\n\treturn 1\n' >"$TMP/sa.gd"
printf 'extends RefCounted\n\n\nfunc f() -> int:\n\treturn SelftestA.new().hello()\n' >"$TMP/sb.gd"
check "$TMP/sa.gd" >/dev/null 2>&1
want_code "script using another class passes" 0 check "$TMP/sb.gd"
printf 'class_name SelftestA\nextends RefCounted\n\n\nfunc renamed() -> int:\n\treturn 1\n' >"$TMP/sa.gd"
want_code "breaking a class is caught in the scripts that use it (cascade)" 2 check "$TMP/sa.gd"
want_text "  ... and names the dependent file" 'sb\.gd'
rm -f "$TMP"/sa.gd* "$TMP"/sb.gd*

touch .captures/.check_stamp
sleep 1.1
printf 'extends RefCounted\n\n\nfunc f() -> int:\n\tvar x = 5\n\treturn x\n' >"$TMP/sneaky.gd"
want_code "edit made outside Edit/Write is caught (--changed)" 2 bash tools/godot_check.sh --changed
rm -f "$TMP"/sneaky.gd*
want_code "  ... and clean again once it is fixed" 0 bash tools/godot_check.sh --changed

HOOK_JSON="$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$(cygpath -m "$PROJECT_ROOT/main.gd" 2>/dev/null || echo "$PROJECT_ROOT/main.gd")")"
LAST_OUT="$(printf '%s' "$HOOK_JSON" | bash tools/godot_check.sh 2>&1)"
if [ $? -eq 0 ]; then ok "hook JSON on stdin is understood"; else no "hook JSON on stdin is understood" "$LAST_OUT"; fi

echo "== logic gate (tools/sim.sh)"
SMOKE=(--plan=res://tests/plans/smoke.json --every=0)
want_code "passing sim exits 0" 0 bash tools/sim.sh "${SMOKE[@]}" --frames=60 --expect="physics_frames>=60"
want_code "failed expectation exits 1" 1 bash tools/sim.sh "${SMOKE[@]}" --frames=60 --expect="physics_frames>=99999"
want_text "  ... and prints the actual value" 'EXPECT FAIL .*actual='
want_code "script error during the run exits 2" 2 bash tools/sim.sh --plan-json='[{"f":2,"key":"NoSuchKey"}]' --every=0 --frames=30
want_text "  ... and prints the error" 'SIM_ERROR'
want_code "hang / crash exits 4" 4 env SIM_TIMEOUT=3 bash tools/sim.sh "${SMOKE[@]}" --frames=100000000
want_code "tunable override typo fails loudly" 2 bash tools/sim.sh "${SMOKE[@]}" --frames=30 --no_waves --spawn_at=0,18 --set=Drowned.no_such_tunable=1
want_code "tunable override is applied" 0 bash tools/sim.sh "${SMOKE[@]}" --frames=30 --no_waves --spawn_at=0,18 --freeze_enemies --set=Drowned.contact_radius=0.5 --expect="overrides.applied==1"
DET=(--plan=res://tests/plans/flare_light.json --every=0 --frames=600 --no_waves --no_lightning --god --place_flare=20 "--spawn_at=3,30;-25,26")
bash tools/sim.sh "${DET[@]}" >/dev/null 2>&1
A="$(grep '^TELEMETRY' .captures/sim/last.log | tail -n 1 | md5sum)"
bash tools/sim.sh "${DET[@]}" >/dev/null 2>&1
B="$(grep '^TELEMETRY' .captures/sim/last.log | tail -n 1 | md5sum)"
if [ "$A" = "$B" ] && [ -n "$A" ]; then ok "same seed gives identical telemetry (determinism)"; else no "same seed gives identical telemetry (determinism)" "final telemetry differs between two runs"; fi
want_code "suite runner works" 0 bash tools/sim.sh --all smoke session_log
want_text "  ... and summarises" 'SUITE 2/2 passed'

echo "== lookups and evidence"
want_code "api.sh answers for an engine class" 0 bash tools/api.sh Node3D global_position
want_text "  ... with the real signature" 'prop +global_position: Vector3'
want_code "api.sh rejects an unknown class" 1 bash tools/api.sh NoSuchClassAnywhere
want_code "api.sh outlines a project class" 0 bash tools/api.sh Drowned shove
want_text "  ... with line numbers" '^[0-9]+:func shove'
want_code "evidence.sh runs" 0 bash tools/evidence.sh 2
want_text "  ... and has all sections" 'SESSION LOG'

if [ "$FAST" -eq 0 ]; then
  echo "== render gates (windows will open)"
  want_code "capture rejects a mistyped preset" 2 bash tools/capture.sh storm_peek
  want_code "capture renders the self-test scene" 0 bash tools/capture.sh test 12
  want_text "  ... with a filmstrip" '^strip: '
  STAT="$(bash tools/img.sh stat .captures/test/f00000006.png)"
  MEAN="$(echo "$STAT" | sed -nE 's/.*mean=([0-9.]+).*/\1/p')"
  if awk "BEGIN{exit !(${MEAN:-0} > 0.01)}"; then ok "rendered frame is not black (mean $MEAN)"; else no "rendered frame is not black" "$STAT"; fi
  LAST_OUT="$(bash tools/img.sh diff .captures/test/f00000006.png .captures/test/f00000006.png)"
  want_text "identical images measure as identical" 'mad=0\.00'
  want_code "visual suite runs on one preset" 0 bash tools/shots.sh calm
  want_text "  ... and classifies it" '^SHOT calm +(SAME|NEW|CHANGED)'
  LAST_OUT="$(SHOT_TOL=0.5 bash tools/img.sh shots dir=.captures/_shots base=.captures/_selftest out=.captures/_selftest calm 2>&1)"
  want_text "  ... a preset without baseline is NEW" '^SHOT calm +NEW'
  mkdir -p .captures/_selftest && cp -f .captures/test/f00000006.png .captures/_selftest/calm.png
  LAST_OUT="$(bash tools/img.sh shots dir=.captures/_shots base=.captures/_selftest out=.captures/_selftest calm 2>&1)"
  want_text "  ... a preset that differs from its baseline is CHANGED, with a pair image" '^SHOT calm +CHANGED .*pair='
  want_code "sweep renders variants into one image" 0 bash tools/sweep.sh calm MoodRig.vfog_density 0.004 0.03
  want_text "  ... and the override reached the game" '^sweep: '
  if echo "$LAST_OUT" | grep -q 'NOT APPLIED'; then no "sweep override applied" "NOT APPLIED reported"; else ok "sweep override applied"; fi

  echo "== stop gate (tools/gate.sh; runs the suite twice)"
  bash tools/sim.sh --all >/dev/null 2>&1
  want_code "green tree: gate lets the turn end" 0 bash -c 'echo "{}" | bash tools/gate.sh'
  cp -f tests/suite.txt "$SUITE_BAK"
  sleep 1.1
  echo "smoke --frames=5 --expect=physics_frames>=999999" >>tests/suite.txt
  want_code "red suite: gate blocks the stop" 2 bash -c 'echo "{}" | bash tools/gate.sh'
  want_text "  ... and names the failure" 'RED'
  want_code "  ... reports the same red state only once" 0 bash -c 'echo "{}" | bash tools/gate.sh'
  sleep 1.1
  touch tests/suite.txt
  want_code "  ... never blocks twice in a row (stop_hook_active)" 0 bash -c 'echo "{\"stop_hook_active\":true}" | bash tools/gate.sh'
  mv -f "$SUITE_BAK" tests/suite.txt
  rm -f .captures/sim/.suite_red
fi

echo "SELFTEST $pass passed, $fail failed"
[ "$fail" -eq 0 ]
