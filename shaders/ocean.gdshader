shader_type spatial;
render_mode world_vertex_coords, blend_mix, cull_back, depth_draw_always, specular_schlick_ggx;
// Gerstner ocean — copied from the godot-ocean-weather skill template, retuned per SPEC §6.1.
// Time and waves are pushed from Ocean.gd so the CPU height query matches exactly.

uniform float wave_time = 0.0;
uniform vec4 waves[4]; // xy = direction, z = steepness (already x wave_scale), w = wavelength (m)

uniform vec3 deep_color : source_color = vec3(0.032, 0.045, 0.055);
uniform vec3 shallow_color : source_color = vec3(0.10, 0.13, 0.15);
uniform vec3 sky_reflect_color : source_color = vec3(0.24, 0.26, 0.30);
uniform vec3 absorption = vec3(0.40, 0.16, 0.12);
uniform float fresnel_power : hint_range(1.0, 10.0) = 5.0;
uniform float foam_threshold : hint_range(0.0, 1.0) = 0.22;
uniform float foam_softness : hint_range(0.01, 0.5) = 0.15;
uniform float shore_foam_width = 1.2;
uniform vec3 foam_color : source_color = vec3(0.76, 0.78, 0.79);
uniform float refraction_strength = 0.04;
uniform float roughness : hint_range(0.0, 1.0) = 0.10;
uniform vec2 edge_fade = vec2(150.0, 196.0); // waves flatten toward the plane edge (meets the flat skirt)

uniform sampler2D foam_noise : repeat_enable, filter_linear_mipmap;
uniform float foam_noise_scale = 0.08;   // per metre
uniform float foam_breakup : hint_range(0.0, 1.0) = 0.5;
uniform vec2 foam_scroll = vec2(0.019, 0.0064); // m/s, wind dir x 0.02
uniform float lace_stretch = 0.25; // lace noise frequency along the wind (streaks follow the wind)

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

varying float v_crest;
varying vec2 v_world_xz;

const float G = 9.81;
const float TAU_ = 6.28318530718;

vec3 gerstner(vec4 w, vec2 p, inout vec3 tangent, inout vec3 binormal) {
	float k = TAU_ / w.w;
	float c = sqrt(G / k);
	vec2 d = normalize(w.xy);
	float f = k * (dot(d, p) - c * wave_time);
	float a = w.z / k;
	float s = sin(f);
	float co = cos(f);
	tangent += vec3(-d.x * d.x * w.z * s, d.x * w.z * co, -d.x * d.y * w.z * s);
	binormal += vec3(-d.x * d.y * w.z * s, d.y * w.z * co, -d.y * d.y * w.z * s);
	return vec3(d.x * a * co, a * s, d.y * a * co);
}

float linear_depth(vec2 uv, float raw, mat4 inv_proj) {
	vec3 ndc = vec3(uv * 2.0 - 1.0, raw); // Forward+ (reverse-Z)
	vec4 v = inv_proj * vec4(ndc, 1.0);
	return -v.z / v.w;
}

void vertex() {
	vec2 p = VERTEX.xz;
	v_world_xz = p;
	vec3 tangent = vec3(1.0, 0.0, 0.0);
	vec3 binormal = vec3(0.0, 0.0, 1.0);
	vec3 offset = vec3(0.0);
	float edge_k = 1.0 - smoothstep(edge_fade.x, edge_fade.y, max(abs(p.x), abs(p.y)));
	for (int i = 0; i < 4; i++) {
		vec4 w = waves[i];
		w.z *= edge_k;
		offset += gerstner(w, p, tangent, binormal);
	}
	VERTEX += offset;
	NORMAL = normalize(cross(binormal, tangent));
	float jacobian = tangent.x * binormal.z - tangent.z * binormal.x;
	v_crest = clamp(1.0 - jacobian, 0.0, 1.0);
}

void fragment() {
	float scene_depth = linear_depth(SCREEN_UV, texture(depth_tex, SCREEN_UV).r, INV_PROJECTION_MATRIX);
	float water_depth = max(scene_depth - (-VERTEX.z), 0.0);

	vec2 refr_uv = SCREEN_UV + NORMAL.xz * refraction_strength * clamp(water_depth, 0.0, 1.0);
	vec3 behind = texture(screen_tex, refr_uv).rgb;
	vec3 transmit = exp(-absorption * water_depth);
	vec3 body = mix(deep_color, behind * shallow_color * 4.0, transmit);

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	vec3 col = mix(body, sky_reflect_color, fresnel);

	// Noise breaks the Jacobian whitecaps into streaky, irregular patches.
	float n = texture(foam_noise, v_world_xz * foam_noise_scale + foam_scroll * wave_time).r;
	float crest = v_crest * mix(1.0, n * 2.0, foam_breakup);
	float crest_foam = smoothstep(foam_threshold, foam_threshold + foam_softness, crest);
	// Fine lace: a second, higher-frequency sample tears the caps into streaks with soft edges.
	vec2 wdir = normalize(foam_scroll + vec2(1e-5, 0.0));
	vec2 lace_uv = vec2(dot(v_world_xz, wdir) * lace_stretch, dot(v_world_xz, vec2(-wdir.y, wdir.x)));
	float lace = texture(foam_noise, lace_uv * foam_noise_scale * 3.7 - vec2(wave_time * 0.03, 0.0)).r;
	float lace_mask = mix(0.3, 1.0, smoothstep(0.38, 0.6, lace));
	crest_foam *= lace_mask * 0.9;
	float shore_n = mix(1.0, n * 1.6, foam_breakup);
	float shore_foam = (1.0 - smoothstep(0.0, shore_foam_width * shore_n, water_depth)) * step(0.001, water_depth);
	shore_foam *= mix(0.35, 1.0, lace_mask) * (1.0 - smoothstep(0.0, shore_foam_width * 0.5, water_depth) * (1.0 - lace_mask));
	float foam = clamp(crest_foam + shore_foam, 0.0, 1.0);

	ALBEDO = mix(col, foam_color, foam);
	ROUGHNESS = mix(roughness, 0.9, foam);
	SPECULAR = 0.5;
	METALLIC = 0.0;
	ALPHA = 1.0;
}
