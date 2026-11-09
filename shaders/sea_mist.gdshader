shader_type fog;
// Low noisy sea mist (SPEC §6.5): thick at the water, thinning with height, drifting with the wind.

uniform float density = 0.025;
uniform vec3 albedo : source_color = vec3(0.60, 0.65, 0.70);
uniform sampler3D noise_tex : repeat_enable, filter_linear;
uniform float noise_scale = 0.035;
uniform float noise_contrast = 1.6;
uniform vec3 wind_offset = vec3(0.0);
uniform float height_falloff = 0.35;
uniform float edge_fade = 0.25;

void fog() {
	vec3 p = (WORLD_POSITION - wind_offset) * noise_scale;
	float n = texture(noise_tex, p).r;
	float base_y = OBJECT_POSITION.y - SIZE.y * 0.5;
	float h = exp(-height_falloff * max(WORLD_POSITION.y - base_y, 0.0));
	vec3 e = smoothstep(vec3(0.0), vec3(edge_fade, edge_fade * 1.5, edge_fade), UVW)
			* smoothstep(vec3(0.0), vec3(edge_fade, edge_fade * 1.5, edge_fade), 1.0 - UVW);
	DENSITY = density * pow(n, noise_contrast) * h * e.x * e.y * e.z;
	ALBEDO = albedo;
}
