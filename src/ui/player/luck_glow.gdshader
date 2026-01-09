shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec2 scale_mult = vec2(1.0);

uniform float aura_progress : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 aura_colour : source_color;
uniform float texture_load_mult : hint_range(0.0, 10.0, 0.01) = 8.0;
uniform float tiling : hint_range(0.0, 60.0, 0.01) = 26.0;

uniform vec2 movment_dir_speed = vec2(-0.6, 1.0);
uniform vec2 movment_dir_speed2 = vec2(0.6, 1.0);

uniform sampler2D color_gradiant : repeat_enable, filter_linear;
uniform vec2 noise_seed = vec2(1.0);

/* ------------------ Noise ------------------ */

vec2 random(vec2 uv){
	uv += noise_seed;
	uv = vec2(
		dot(uv, vec2(127.1, 311.7)),
		dot(uv, vec2(269.5, 183.3))
	);
	return -1.0 + 2.0 * fract(sin(uv) * 43758.5453123);
}

float noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	vec2 u = f * f * (3.0 - 2.0 * f);

	float a = dot(random(i), f);
	float b = dot(random(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(random(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(random(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));

	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 0.5 + 0.5;
}

/* ------------------ Aura ------------------ */

void fragment() {
	vec2 time_uv1 = movment_dir_speed * TIME;
	vec2 time_uv2 = movment_dir_speed2 * TIME;

	vec2 scale_offset = (1.0 - scale_mult) * 0.5;
	vec2 compos_uv = UV * scale_mult + scale_offset;

	// Base texture (REPLACES COLOR reads)
	vec4 base = texture(TEXTURE, compos_uv);

	// Fake "LOD wobble" via UV distortion
	float n1 = noise(UV * tiling + time_uv1);
	vec2 distorted_uv = compos_uv + (n1 - 0.5) * 0.01 * texture_load_mult;

	vec4 alpha = texture(TEXTURE, distorted_uv);

	// Gradient cycling around rectangle
	vec4 gradient = texture(
		color_gradiant,
		fract(vec2(-UV.y, UV.x) + time_uv1 * 0.4)
	) * 3.0;

	vec4 aura = gradient * noise(UV * tiling - time_uv1);
	aura.a = alpha.a
		* noise(UV * tiling + time_uv1)
		* noise(UV * tiling + time_uv2)
		* 5.0;

	COLOR = mix(base, aura * aura_progress, 1.0 - base.a) * aura_colour;
}
