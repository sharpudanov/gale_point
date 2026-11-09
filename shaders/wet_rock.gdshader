shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;
// Triplanar wet black rock for the island terrain (SPEC §6.3).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_tex : hint_roughness_g, filter_linear_mipmap, repeat_enable;
uniform sampler2D ao_tex : filter_linear_mipmap, repeat_enable;
uniform float triplanar_scale = 0.18;
uniform float blend_sharpness = 4.0;
uniform float darken = 0.55;
uniform vec3 wet_tint : source_color = vec3(0.88, 0.90, 0.95);
uniform float wetness : hint_range(0.0, 1.0) = 0.85;
uniform float wet_roughness = 0.50;
uniform sampler2D puddle_noise : repeat_enable, filter_linear_mipmap;
uniform float puddle_scale = 0.05;
uniform float puddle_threshold = 0.62;
uniform float puddle_roughness = 0.20;
uniform float flat_slope = 0.92;
uniform float normal_strength = 1.2;
uniform float ao_strength = 1.0;

varying vec3 v_wpos;
varying vec3 v_wnormal;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 unpack_n(vec3 t) {
	vec3 n = t * 2.0 - 1.0;
	n.xy *= normal_strength;
	return normalize(n);
}

void fragment() {
	vec3 wn = normalize(v_wnormal);
	vec3 w = pow(abs(wn), vec3(blend_sharpness));
	w /= (w.x + w.y + w.z);
	vec3 p = v_wpos * triplanar_scale;
	vec2 uv_x = p.zy;
	vec2 uv_y = p.xz;
	vec2 uv_z = p.xy;

	vec3 alb = texture(albedo_tex, uv_x).rgb * w.x + texture(albedo_tex, uv_y).rgb * w.y + texture(albedo_tex, uv_z).rgb * w.z;
	float rough = texture(roughness_tex, uv_x).g * w.x + texture(roughness_tex, uv_y).g * w.y + texture(roughness_tex, uv_z).g * w.z;
	float ao = texture(ao_tex, uv_x).r * w.x + texture(ao_tex, uv_y).r * w.y + texture(ao_tex, uv_z).r * w.z;

	// Whiteout-blended triplanar normals in world space.
	vec3 tx = unpack_n(texture(normal_tex, uv_x).rgb);
	vec3 ty = unpack_n(texture(normal_tex, uv_y).rgb);
	vec3 tz = unpack_n(texture(normal_tex, uv_z).rgb);
	tx = vec3(tx.xy + wn.zy, abs(tx.z) * wn.x);
	ty = vec3(ty.xy + wn.xz, abs(ty.z) * wn.y);
	tz = vec3(tz.xy + wn.xy, abs(tz.z) * wn.z);
	vec3 n_world = normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);

	// Puddles: flat ground where the noise is high turns mirror-smooth and flat.
	float flatness = smoothstep(flat_slope - 0.03, flat_slope + 0.02, wn.y);
	float pn = texture(puddle_noise, v_wpos.xz * puddle_scale).r;
	float puddle = smoothstep(puddle_threshold, puddle_threshold + 0.06, pn) * flatness * wetness;
	n_world = normalize(mix(n_world, wn, puddle));

	vec3 wet_alb = alb * darken * mix(vec3(1.0), wet_tint, wetness);
	ALBEDO = wet_alb * (1.0 - puddle * 0.35);
	ROUGHNESS = mix(mix(rough, wet_roughness, wetness), puddle_roughness, puddle);
	SPECULAR = (0.3 + 0.1 * wetness) * (1.0 - puddle * 0.5);  // keeps moonlit rock from clipping to snow-white
	AO = mix(1.0, ao, ao_strength);
	AO_LIGHT_AFFECT = 0.2;
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
}
