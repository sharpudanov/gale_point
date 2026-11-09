shader_type canvas_item;
// Film finish (SPEC §6.6): shadow-biased grain, vignette, slight desaturation, cold black lift,
// damage vignette and fade to black.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float grain_amount = 0.035;
uniform float grain_size = 1.4;           // pixels
uniform float grain_shadow_bias = 0.6;
uniform float grain_seed = 0.0;           // pushed per frame
uniform float vignette_strength = 0.32;
uniform float vignette_radius = 0.78;
uniform float vignette_softness = 0.45;
uniform float saturation = 0.92;
uniform vec3 black_lift = vec3(0.018, 0.021, 0.028);
uniform float damage = 0.0;
uniform float fade = 0.0;
uniform vec3 fade_color = vec3(0.01, 0.012, 0.015);

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(lum), c, saturation);

	// Vignette (aspect-corrected), plus the cold damage edge.
	vec2 q = (SCREEN_UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float r = length(q) * 1.414;
	float vig = smoothstep(vignette_radius - vignette_softness, vignette_radius + vignette_softness * 0.5, r);
	c *= 1.0 - vig * vignette_strength;
	float edge = smoothstep(0.25, 1.1, r);
	c = mix(c, vec3(dot(c, vec3(0.299, 0.587, 0.114))), edge * damage * 0.45);
	c *= 1.0 - edge * damage * 0.55;

	// Grain: per-frame hash in grain_size cells, stronger in the shadows.
	vec2 cell = floor(FRAGCOORD.xy / grain_size);
	float g = hash(cell + grain_seed * 17.31) - 0.5;
	float shadow_w = mix(1.0, 1.0 - smoothstep(0.0, 0.5, lum), grain_shadow_bias);
	c += g * grain_amount * (0.4 + shadow_w);

	c = black_lift + c * (1.0 - black_lift);
	c = mix(c, fade_color, fade);
	COLOR = vec4(max(c, vec3(0.0)), 1.0);
}
