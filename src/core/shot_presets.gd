class_name ShotPresets
extends RefCounted
## SPEC §9: each capture preset is a bundle of §7 debug-arg defaults (explicit args still win).
## The camera pose comes from --player_at / --look, so every preset uses the real player camera.

const PRESETS: Dictionary = {
	"calm": "--night_t=15 --no_waves --no_lightning --player_at=0,7 --look=180,-4 --beam_yaw=150",
	"storm_peak": "--night_t=270 --no_waves --no_lightning --player_at=12,14 --look=225,-6 --spawn_at=30,45;40,40;22,55",
	"lightning": "--night_t=200 --no_waves --flash_at=0.80 --player_at=0,7 --look=180,-3 --freeze_enemies --spawn_at=-8,32;-3,38;4,30;10,42;15,36",
	"flare_fight": "--night_t=150 --no_waves --no_lightning --player_at=0,7 --look=180,-5 --place_flare=14 --spawn_at=-3,23;4,19;-12,27;11,30 --aim --fire_at=0.98",
	"dawn": "--night_t=320 --no_waves --player_at=-6,-10 --look=270,2",
	"drowned_close": "--night_t=120 --no_waves --no_lightning --player_at=0,7 --look=180,-2 --freeze_enemies --place_flare=18 --spawn_at=0.5,11;-3,16",
}


static func has_preset(preset: String) -> bool:
	return PRESETS.has(preset)


## Default args for a preset as a key -> value map (bare flags map to true).
static func defaults(preset: String) -> Dictionary:
	var out: Dictionary = {}
	if not PRESETS.has(preset):
		return out
	for token: String in str(PRESETS[preset]).split(" ", false):
		var body: String = token.trim_prefix("--")
		var eq: int = body.find("=")
		if eq < 0:
			out[body] = true
		else:
			out[body.substr(0, eq)] = body.substr(eq + 1)
	return out
