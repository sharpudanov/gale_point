shader_type sky;
// Storm / dawn HDRI sky (SPEC §6.2). Night: ash + bruise-purple, desaturated. Dawn: cold silver.

uniform sampler2D storm_hdri : source_color, filter_linear, repeat_enable;
uniform sampler2D dawn_hdri : source_color, filter_linear, repeat_enable;
uniform float hdri_energy = 0.22;
uniform float dawn_mix : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tint_night : source_color = vec3(0.80, 0.78, 0.92);
uniform vec3 tint_dawn : source_color = vec3(0.92, 0.93, 0.98);
uniform float desaturate : hint_range(0.0, 1.0) = 0.6;
uniform float flash = 0.0;
uniform vec3 flash_color : source_color = vec3(0.80, 0.86, 1.0);
uniform float flash_gain = 2.5;
uniform float hdri_yaw = 0.0; // radians
uniform vec3 horizon_haze : source_color = vec3(0.20, 0.22, 0.26);
uniform float horizon_haze_height = 0.12;
uniform vec3 below_horizon : source_color = vec3(0.03, 0.035, 0.045);

const float PI_ = 3.14159265359;
const float TAU_ = 6.28318530718;

vec3 sample_hdri(sampler2D tex, vec2 uv) {
	return textureLod(tex, uv, 0.0).rgb; // lod 0: no mip seam at the wrap
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float horizon_y = max(dir.y, 0.0);
	// Sample just above the horizon for the below-horizon band so the seam stays soft.
	vec3 sdir = normalize(vec3(dir.x, max(dir.y, 0.005), dir.z));
	vec2 uv = vec2(fract(atan(sdir.x, -sdir.z) / TAU_ + 0.5 + hdri_yaw / TAU_), acos(sdir.y) / PI_);

	vec3 night = sample_hdri(storm_hdri, uv);
	vec3 dawn = sample_hdri(dawn_hdri, uv);
	vec3 raw = mix(night, dawn, dawn_mix);
	float lum = dot(raw, vec3(0.2126, 0.7152, 0.0722));

	vec3 c = mix(raw, vec3(lum), desaturate);
	c *= mix(tint_night, tint_dawn, dawn_mix);
	c *= hdri_energy;

	// Lightning lights the clouds, weighted by HDRI luminance (thick clouds glow most).
	c += flash_color * flash * flash_gain * clamp(lum, 0.0, 2.0) * hdri_energy * 4.0;

	float haze = 1.0 - smoothstep(0.0, horizon_haze_height, horizon_y);
	c = mix(c, horizon_haze * mix(1.0, 2.6, dawn_mix) + flash_color * flash * 0.4, haze * 0.75);

	// Just below the horizon (seen past the camera far plane) continue the haze, not black.
	vec3 haze_col = horizon_haze * mix(1.0, 2.6, dawn_mix);
	vec3 under = mix(mix(c, haze_col, 0.75), below_horizon, smoothstep(-0.03, -0.2, dir.y));
	COLOR = dir.y >= 0.0 ? c : under;
}
