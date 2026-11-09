class_name GameRng
extends RefCounted
## Single seeded RNG for the whole game (SPEC §3 determinism). Every random draw goes through here.

static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
static var _seed: int = 1


static func seed_with(value: int) -> void:
	_seed = value
	_rng.seed = value
	_rng.state = 0
	_rng.seed = value


static func get_seed() -> int:
	return _seed


static func randf() -> float:
	return _rng.randf()


static func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


static func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## A fresh integer seed for sub-generators (noise, audio synthesis).
static func next_seed() -> int:
	return _rng.randi() & 0x7fffffff
