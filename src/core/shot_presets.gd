class_name ShotPresets
extends RefCounted
## SPEC §9: each capture preset is a bundle of §7 debug-arg defaults (explicit args still win).
## The camera pose comes from --player_at / --look, so every preset uses the real player camera.

const PRESETS: Dictionary = {
	"calm": "--night_t=15 --no_waves --no_lightning --player_at=0,7 --look=180,-4 --beam_yaw=150",
	"storm_peak": "--night_t=270 --no_waves --no_lightning --player_at=12,14 --look=225,-6 --spawn_at=30,45;40,40;22,55",
	"lightning": "--night_t=200 --no_waves --flash_at=0.80 --player_at=0,7 --look=180,-3 --freeze_enemies --spawn_at=-8,32;-3,38;4,30;10,42;15,36",
	"flare_fight": "--night_t=150 --no_waves --no_lightning --player_at=0,7 --look=180,-5 --place_flare=14 --spawn_at=-3,23;4,19;-13,28;11,30 --aim --fire_at=0.98",
	"ads_aim": "--night_t=150 --no_waves --no_lightning --player_at=0,7 --look=180,-4 --place_flare=16 --spawn_at=0,21 --ads",
	"ads_close": "--night_t=150 --no_waves --no_lightning --player_at=0,7 --look=180,-2 --place_flare=10 --spawn_at=0,19 --freeze_enemies --ads",
	"hit_lit": "--night_t=150 --no_waves --no_lightning --player_at=0,7 --look=180,-4 --freeze_enemies --place_flare=16 --spawn_at=0,18 --aim --fire_at=0.5",
	"hit_dark": "--night_t=120 --no_waves --no_lightning --player_at=0,7 --look=180,-4 --freeze_enemies --spawn_at=0,18 --aim --fire_at=0.5",
	"dawn": "--night_t=320 --no_waves --player_at=-6,-10 --look=270,2",
	"dawn_sink": "--night_t=309 --no_lightning --player_at=0,7 --look=180,-2 --freeze_enemies --spawn_at=-3,16;4,20;-8,26;9,30",
	"dawn_card": "--night_t=319 --no_waves --player_at=-6,-10 --look=270,2",
	"wounded_dark": "--night_t=120 --no_waves --no_lightning --player_at=0,7 --look=180,-3 --freeze_enemies --pre_trails --spawn_at=0.6,14;-3.5,19 --spawn_hp=45",
	"captain": "--night_t=150 --no_waves --no_lightning --player_at=0,7 --look=180,-3 --freeze_enemies --pre_trails --spawn_at=0.5,16;-3,20;3.5,21 --spawn_kind=captain",
	"torch": "--night_t=150 --no_waves --no_lightning --player_at=0,7 --look=180,-3 --freeze_enemies --spawn_at=0.5,17;-3,20;3.5,21 --impale_first",
	"flare_burst": "--night_t=150 --no_waves --no_lightning --player_at=0,7 --look=180,-4 --freeze_enemies --place_flare=12 --spawn_at=2,20;-2,17 --aim_flare --fire_at=0.6",
	"brazier": "--night_t=150 --no_waves --no_lightning --player_at=13,8.5 --look=242,-5 --light_braziers --spawn_at=17,13;20,17 --freeze_enemies",
	"bells": "--night_t=150 --no_waves --no_lightning --player_at=0,7 --look=180,1 --toll=3",
	"overdrive": "--night_t=150 --no_waves --no_lightning --player_at=9,-5 --look=10,-4 --overdrive --freeze_enemies --spawn_at=-3,-44;4,-48;0,-52",
	"shove": "--night_t=120 --no_waves --no_lightning --player_at=0,7 --look=180,-12 --freeze_enemies --spawn_at=0,9.3 --spawn_hp=60 --shove_at=0.85",
	"drowned_close": "--night_t=120 --no_waves --no_lightning --player_at=0,7 --look=180,-2 --freeze_enemies --pre_trails --place_flare=18 --spawn_at=0.5,11;-3,16",
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
