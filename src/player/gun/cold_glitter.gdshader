shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

/** Noise used for the glitter shape.
* A high frequency is recommended (for example 0.15), but finetune to taste.
* If using an Atlas or Non-Squared texture, the Noise Texture MUST be of the same aspect ratio.
* It is necessary to set up the noise correctly. On the Noise Texture -> Noise create a FastNoiseLite
* This FastNoiseLite works best with Perlin Noise Type for realistic glitter, or Cellular Noise Type (and turning on Noise Texture -> Invert) for a more rounded shape.
* Using Fractal and Domain Warp inside the FastNoiseLite can help creating a more organic glitter shape.
*/
uniform sampler2D noise_texture : repeat_enable;

// The sprite's own texture — assign the same texture you'd put on the Sprite3D itself.
uniform sampler2D texture_albedo : source_color, hint_default_white;

// Glitter properties
group_uniforms GlitterProperties;
uniform vec4 glitter_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float glitter_size : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float glitter_hardness : hint_range(0.0, 1.0, 0.01) = 0.35;

group_uniforms HighlightProperties;
/** Glitter highlight speed. */
uniform float highlight_speed = 10.0;
/** Glitter highlight intensity. */
uniform float highlight_intensity : hint_range(0.0, 1.0, 0.05) = 0.25;
/** Glitter highlight band*/
uniform bool highlight_band;

varying vec2 local_vert;

void vertex() {
	// VERTEX in spatial shaders is object-space (vec3); use xy like the original local_vert.
	local_vert = VERTEX.xy;
}

void fragment() {
	float glitter_highlight_map = (
			mix(
				texture(noise_texture, (local_vert * 0.005) + TIME * highlight_speed * 0.01).r,
				sin((local_vert.x + local_vert.y) * 0.05 + TIME * highlight_speed) * 0.5 + 1.0,
				float(highlight_band)
				)
		);

	// Generate glitter shapes
	float glitter = (
		// Filter the noise to get the glitter shapes
		smoothstep(
			(1.0 - glitter_size),
			1.0 - (glitter_size * glitter_hardness),
			texture(noise_texture, UV).r
			)
		// Apply the highlight map on the glitter.
		* (1.0 - (glitter_highlight_map * clamp(highlight_intensity, 0.0, 0.65)))
		);

	// Get the Sprite texture
	vec4 sprite_texture = texture(texture_albedo, UV);

	vec4 final_color = mix(sprite_texture, glitter_color, glitter * sprite_texture.a);

	ALBEDO = final_color.rgb;
	ALPHA = sprite_texture.a;

	// This is for debug. Uncommenting this will show the Glitter Highlight Map
	//ALBEDO = vec3(glitter_highlight_map);
}