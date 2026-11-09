shader_type spatial;
render_mode world_vertex_coords, blend_mix, cull_back, depth_draw_always, specular_schlick_ggx;

// Fed from GDScript every frame (Ocean.gd) so CPU and GPU waves can never drift.
uniform float wave_time = 0.0;
uniform vec4 waves[4]; // xy = direction, z = steepness (0..1, sum < 1), w = wavelength (m)

uniform vec3 deep_color : source_color = vec3(0.02, 0.07, 0.09);
uniform vec3 shallow_color : source_color = vec3(0.10, 0.26, 0.27);
uniform vec3 sky_reflect_color : source_color = vec3(0.32, 0.37, 0.42);
uniform vec3 absorption = vec3(0.45, 0.12, 0.09); // per-channel extinction per metre (red dies first)
uniform float fresnel_power : hint_range(1.0, 10.0) = 5.0;
uniform float foam_threshold : hint_range(0.0, 1.0) = 0.3;  // on (1 - Jacobian); ~0.5 x steepness sum
uniform float foam_softness : hint_range(0.01, 0.5) = 0.15;
uniform float shore_foam_width = 0.6;
uniform vec3 foam_color : source_color = vec3(0.78, 0.80, 0.80);
uniform float refraction_strength = 0.04;
uniform float roughness : hint_range(0.0, 1.0) = 0.08;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

varying float v_crest; // 1 - Jacobian: 0 = flat/stretched, high = compressed crest about to fold

const float G = 9.81;
const float TAU_ = 6.28318530718;

vec3 gerstner(vec4 w, vec2 p, inout vec3 tangent, inout vec3 binormal, inout float amp_sum) {
	float k = TAU_ / w.w;
	float c = sqrt(G / k);
	vec2 d = normalize(w.xy);
	float f = k * (dot(d, p) - c * wave_time);
	float a = w.z / k;
	float s = sin(f);
	float co = cos(f);
	tangent += vec3(-d.x * d.x * w.z * s, d.x * w.z * co, -d.x * d.y * w.z * s);
	binormal += vec3(-d.x * d.y * w.z * s, d.y * w.z * co, -d.y * d.y * w.z * s);
	amp_sum += a;
	return vec3(d.x * a * co, a * s, d.y * a * co);
}

float linear_depth(vec2 uv, float raw, mat4 inv_proj) {
	vec3 ndc = vec3(uv * 2.0 - 1.0, raw); // Forward+/Mobile (reverse-Z)
	vec4 v = inv_proj * vec4(ndc, 1.0);
	return -v.z / v.w;
}

void vertex() {
	vec2 p = VERTEX.xz; // world space thanks to world_vertex_coords
	vec3 tangent = vec3(1.0, 0.0, 0.0);
	vec3 binormal = vec3(0.0, 0.0, 1.0);
	float amp_sum = 0.0;
	vec3 offset = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		offset += gerstner(waves[i], p, tangent, binormal, amp_sum);
	}
	VERTEX += offset;
	NORMAL = normalize(cross(binormal, tangent));
	float jacobian = tangent.x * binormal.z - tangent.z * binormal.x; // <1 = squeezed, ~0 = folding
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

	float crest_foam = smoothstep(foam_threshold, foam_threshold + foam_softness, v_crest);
	float shore_foam = 1.0 - smoothstep(0.0, shore_foam_width, water_depth);
	float foam = clamp(crest_foam + shore_foam, 0.0, 1.0);

	ALBEDO = mix(col, foam_color, foam);
	ROUGHNESS = mix(roughness, 0.9, foam);
	SPECULAR = 0.5;
	METALLIC = 0.0;
	ALPHA = 1.0; // forces the transparent pass so screen/depth textures contain the scene
}
