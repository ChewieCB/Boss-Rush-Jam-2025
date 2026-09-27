shader_type canvas_item;
// Colored edge glow + chromatic aberration that grows toward the screen edges.

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(0.45, 0.9, 1.0, 1.0);
uniform float edge_glow : hint_range(0.0, 2.0) = 0.55;
uniform float aberration_strength : hint_range(0.0, 0.1) = 0.018;
// Radii in screen space: 0 = center, 1 = middle of the screen edges, ~1.41 = corners
uniform float inner_radius : hint_range(0.0, 1.5) = 0.35;
uniform float outer_radius : hint_range(0.0, 2.0) = 1.25;

void fragment() {
	vec2 from_center = SCREEN_UV - vec2(0.5);
	float edge = smoothstep(inner_radius, outer_radius, length(from_center * 2.0));

	vec2 offset = from_center * aberration_strength * intensity * edge;
	float r = texture(SCREEN_TEXTURE, SCREEN_UV + offset).r;
	float g = texture(SCREEN_TEXTURE, SCREEN_UV).g;
	float b = texture(SCREEN_TEXTURE, SCREEN_UV - offset).b;

	vec3 col = vec3(r, g, b) + edge_color.rgb * edge_color.a * edge * edge_glow * intensity;
	COLOR = vec4(col, 1.0);
}
