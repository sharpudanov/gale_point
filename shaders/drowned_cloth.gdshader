shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// The Drowned's cloak and sleeves (SPEC 6.4). Vertex flutter weighted by (1 - UV.y)^p so the hood is
// fixed and the hem moves most; tattered hem and death dissolve are alpha-scissored by noise.
// No emission and no rim term, ever (SPEC 5.1).

uniform vec4 cloth_color : source_color = vec4(0.035, 0.04, 0.045, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.75;
uniform float specular : hint_range(0.0, 1.0) = 0.25;
uniform vec2 wind_dir = vec2(0.95, 0.32);
uniform float wind_strength : hint_range(0.0, 1.5) = 0.5;
uniform float flutter_amp = 0.2;
uniform float flutter_freq = 2.3;
uniform float flutter_wavelength = 0.9;
uniform float hem_weight_pow = 1.2;
uniform sampler2D tatter_tex : repeat_enable, filter_linear;
uniform float tatter_threshold = 0.6;
uniform float tatter_band = 0.3;
uniform sampler2D detail_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D detail_rough : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec2 detail_tiling = vec2(7.0, 4.0);
uniform float detail_normal_depth = 0.8;

instance uniform float time_offset = 0.0;
instance uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
instance uniform float flutter_scale = 1.0;
instance uniform vec3 drag_offset = vec3(0.0);   // model space: -velocity * 0.12

void vertex() {
	float w = pow(clamp(1.0 - UV.y, 0.0, 1.0), hem_weight_pow);
	float t = TIME + time_offset;
	float k = 6.28318 / flutter_wavelength;
	float phase = atan(VERTEX.z, VERTEX.x) * 2.0;
	float sway = sin(k * VERTEX.y - 6.28318 * flutter_freq * t + phase) * flutter_amp * flutter_scale;
	vec3 wind_local = (inverse(MODEL_MATRIX) * vec4(wind_dir.x, 0.0, wind_dir.y, 0.0)).xyz;
	// The flutter pushes outward along the radial direction as well as sideways, so the hem billows.
	vec3 radial = normalize(vec3(VERTEX.x, 0.0, VERTEX.z) + vec3(0.0001));
	vec3 off = radial * sway + wind_local * wind_strength * 0.25 + drag_offset;
	VERTEX += off * w;
}

void fragment() {
	float n = texture(tatter_tex, UV * vec2(3.0, 2.0)).r;
	// Tatters: in the lower band the cut-off rises toward the hem, eating notches out of it.
	float band = clamp(1.0 - UV.y / tatter_band, 0.0, 1.0);
	float cut = tatter_threshold * band * band;
	// Dissolve: low-frequency noise (big ragged patches, not speckle), sweeping from the hem upward.
	float nd = texture(tatter_tex, UV * vec2(1.1, 0.7) + vec2(0.37, 0.11)).r;
	float dis_cut = dissolve * 1.15 - (UV.y * 0.15);
	float keep = step(cut, n) * step(dis_cut, nd);
	if (keep < 0.5) {
		discard;
	}
	vec2 duv = UV * detail_tiling;
	ALBEDO = cloth_color.rgb;
	ROUGHNESS = clamp(roughness * (0.6 + 0.8 * texture(detail_rough, duv).g), 0.0, 1.0);
	SPECULAR = specular;
	NORMAL_MAP = texture(detail_normal, duv).xyz;
	NORMAL_MAP_DEPTH = detail_normal_depth;
}
