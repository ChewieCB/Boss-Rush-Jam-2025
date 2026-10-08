shader_type canvas_item;
// Vignette that closes in toward the center as intensity goes up.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 0.85);
// Radii in screen space: 0 = center, 1 = middle of the screen edges, ~1.41 = corners
// At full intensity the vignette start darkening from inner_radius, fully dark at outer_radius
uniform float inner_radius : hint_range(0.0, 1.5) = 0.5;
uniform float outer_radius : hint_range(0.0, 2.0) = 1.4;

void fragment() {
	float dist = length((UV - vec2(0.5)) * 2.0);
	// Inner edge slide from outer_radius to inner_radius so it feel like closing in
	float current_inner = mix(outer_radius, inner_radius, intensity);
	float dark = smoothstep(current_inner, outer_radius, dist);
	COLOR = vec4(vignette_color.rgb, vignette_color.a * dark * intensity);
}
