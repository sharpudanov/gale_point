shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// The Drowned's cloak and sleeves (SPEC 6.4). Vertex flutter weighted by (1 - UV.y)^p so the hood is
// fixed and the hem moves most; tattered hem and death dissolve are alpha-scissored by noise.
// The only emission is the "searing" state (SPEC 5.1): while the Drowned stands in gameplay light
// (lit_amount > 0) an ember rim and cracks glow on the hood and shoulders, and the cracks widen and brighten
// as its hp (damage_amount) drops. Otherwise it is pure unlit cloth: no emission, no rim.

uniform vec4 cloth_color : source_color = vec4(0.035, 0.04, 0.045, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.75;
uniform float specular : hint_range(0.0, 1.0) = 0.25;
uniform vec2 wind_dir = vec2(0.95, 0.32);
uniform float wind_strength : hint_range(0.0, 1.5) = 0.5;
uniform float flutter_amp = 0.14;
uniform float flutter_freq = 2.3;
uniform float flutter_wavelength = 0.9;
uniform float hem_weight_pow = 2.0;   // UV.y is height (0 hem, 1 hood tip): the upper body holds its shape
uniform sampler2D tatter_tex : repeat_enable, filter_linear_mipmap;   // mipmaps: thin cracks must not sparkle at range
uniform float tatter_threshold = 0.6;
uniform float tatter_band = 0.22;
uniform sampler2D detail_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D detail_rough : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec2 detail_tiling = vec2(7.0, 4.0);
uniform float detail_normal_depth = 0.8;
uniform vec3 ember_color : source_color = vec3(1.0, 0.55, 0.22);
uniform float ember_energy = 2.2;
uniform float rim_power = 5.0;
uniform vec2 crack_tiling = vec2(2.0, 1.4);   // few long veins: a fine pattern reads as glitter
uniform float crack_width_min = 0.02;    // crack half-width in noise units at full hp
uniform float crack_width_max = 0.06;    // ... and at 0 hp
uniform float crack_patch_full_hp = 0.5;   // patch noise above this shows veins at full hp (higher = fewer)
uniform float crack_patch_dying = 0.15;    // ... and at 0 hp
uniform float crack_strength_full_hp = 0.6;
uniform float crack_strength_dying = 2.2;
uniform float rim_strength = 0.4;        // grazing ember rim while lit; keep it a hint, never an outline

instance uniform float time_offset = 0.0;
instance uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
instance uniform float flutter_scale = 1.0;
instance uniform vec3 drag_offset = vec3(0.0);   // model space: -velocity * 0.12
instance uniform float lit_amount : hint_range(0.0, 1.0) = 0.0;      // 1 = searing in the light (shootable)
instance uniform float damage_amount : hint_range(0.0, 1.0) = 0.0;   // 1 - hp / max_hp
instance uniform float smolder_amount : hint_range(0.0, 2.0) = 0.0;  // wounded: embers in the cracks even in the dark
instance uniform float burn_amount : hint_range(0.0, 1.0) = 0.0;     // on fire (impaled flare / oil): whole cloak chars

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
	float n = texture(tatter_tex, UV * vec2(6.0, 2.0)).r;   // narrow notches: wide ones read as legs
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
	if (lit_amount > 0.001 || smolder_amount > 0.001 || burn_amount > 0.001) {
		// Hood and shoulders (UV.y near 1) glow most; the hem only a little.
		float upper = mix(0.25, 1.0, smoothstep(0.2, 0.8, UV.y));
		float rim = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), rim_power);   // abs: the lathe winding flips NORMAL
		// Cracks: thin ridges of the noise (|n - 0.5| small). They widen and brighten as hp drops.
		float cn = texture(tatter_tex, UV * crack_tiling + vec2(0.13, 0.71)).r;
		float half_w = mix(crack_width_min, crack_width_max, damage_amount);
		float crack = 1.0 - smoothstep(half_w * 0.4, half_w, abs(cn - 0.5));
		// The veins only break through in patches; the patches spread over the whole cloak as hp drops.
		float patch_n = texture(tatter_tex, UV * vec2(1.0, 0.6) + vec2(0.62, 0.35)).r;
		float patch_edge = mix(crack_patch_full_hp, crack_patch_dying, damage_amount);
		crack *= smoothstep(patch_edge, patch_edge + 0.12, patch_n);
		float flicker = 0.85 + 0.15 * sin(TIME * 9.0 + time_offset * 3.0 + UV.y * 20.0);
		float strength = rim * rim_strength + crack * mix(crack_strength_full_hp, crack_strength_dying, damage_amount);
		vec3 e = ember_color * ember_energy * strength * upper * flicker * lit_amount;
		// Smolder (wounded, any light): only the cracks, with a ragged fast crackle; no rim, so it stays a
		// wound and never reads as an outline.
		float crackle = 0.55 + 0.45 * texture(tatter_tex, UV * vec2(2.0, 1.3) + vec2(TIME * 0.31 + time_offset, TIME * 0.17)).r;
		crackle *= 0.8 + 0.2 * sin(TIME * 23.0 + time_offset * 5.0 + UV.x * 31.0);
		// Thin fixed-width seams on hood and shoulders only (not the hem), so a wound reads as a few live
		// embers in the folds rather than a sparkle over the whole cloak.
		// Low-frequency noise stretched vertically: 3-5 long connected seams, not a grain pattern.
		float sn = texture(tatter_tex, UV * vec2(1.6, 0.45) + vec2(0.41, 0.23)).r;
		float seam = 1.0 - smoothstep(0.008, 0.02, abs(sn - 0.5));
		float shoulders = smoothstep(0.45, 0.85, UV.y);
		float pulse = 0.7 + 0.3 * sin(TIME * 1.9 + time_offset);   // ~0.3 Hz breathing glow
		e += ember_color * ember_energy * 0.6 * seam * pulse * shoulders * smolder_amount;
		// Burning (impaled flare / oil): the cracks blow wide open and the hem chars with crawling fire.
		// Low-frequency only (the fine crack noise reads as glitter at range): broad charred seams and
		// slow tongues of flame crawling up from the hem.
		float burn_crack = 1.0 - smoothstep(0.03, 0.07, abs(sn - 0.5));
		float flames = smoothstep(0.55, 0.8, texture(tatter_tex, UV * vec2(1.2, 0.6) + vec2(time_offset, -TIME * 0.35)).r);
		float climb = mix(1.0, 0.35, UV.y);   // fire licks up from the hem; the hood chars
		e += ember_color * ember_energy * (burn_crack * 0.6 + flames * 0.7 * climb) * pulse * burn_amount;
		EMISSION = e;
		ALBEDO *= 1.0 - 0.6 * burn_amount;   // charred
	}
}
