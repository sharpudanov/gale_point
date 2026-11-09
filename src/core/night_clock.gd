class_name NightClock
extends Node
## Night timer (SPEC §4.1). Phase: night -> dawn -> won; `dead` overrides and freezes the clock.

signal dawn_started
signal won

@export var night_len: float = 300.0
@export var dawn_len: float = 20.0  ## seconds at night_len 300; scaled by k

var night_t: float = 0.0
var phase: String = "night"


func setup(start_t: float, length: float) -> void:
	night_len = length
	night_t = maxf(0.0, start_t)
	phase = _phase_for_time()


## Schedule scale k = night_len / 300 (SPEC §3).
func k() -> float:
	return night_len / 300.0


func dawn_len_scaled() -> float:
	return dawn_len * k()


func u() -> float:
	return clampf(night_t / night_len, 0.0, 1.0)


func dawn_progress() -> float:
	return clampf((night_t - night_len) / dawn_len_scaled(), 0.0, 1.0)


func set_dead() -> void:
	phase = "dead"


func _physics_process(delta: float) -> void:
	if phase == "dead" or phase == "won":
		return
	night_t += delta
	var p: String = _phase_for_time()
	if p != phase:
		phase = p
		if phase == "dawn":
			dawn_started.emit()
		elif phase == "won":
			won.emit()


func _phase_for_time() -> String:
	if night_t < night_len:
		return "night"
	if dawn_progress() < 1.0:
		return "dawn"
	return "won"
