shader_type canvas_item;

// Procedural crosshair: 4 rectangles + center dot, with outline. All sizes are in canvas pixels.
uniform vec2 rect_size = vec2(32.0);
uniform vec2 gap = vec2(4.0);
uniform float line_length = 9.0;
uniform float thickness = 2.0;
uniform float dot_size = 2.0;
uniform float outline_width = 1.0;
uniform vec4 line_color : source_color = vec4(1.0);
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

float sd_box(vec2 p, vec2 center, vec2 half_extents) {
	vec2 d = abs(p - center) - half_extents;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

void fragment() {
	// Fold into one quadrant so each tick pair is a single box.
	vec2 q = abs((UV - 0.5) * rect_size);
	float half_len = line_length * 0.5;
	float half_thick = thickness * 0.5;

	float d = sd_box(q, vec2(gap.x + half_len, 0.0), vec2(half_len, half_thick));
	d = min(d, sd_box(q, vec2(0.0, gap.y + half_len), vec2(half_thick, half_len)));
	if (dot_size > 0.0) {
		d = min(d, sd_box(q, vec2(0.0), vec2(dot_size * 0.5)));
	}

	float fill = clamp(0.5 - d, 0.0, 1.0);
	float outer = clamp(0.5 - (d - outline_width), 0.0, 1.0);
	vec4 col = mix(outline_color, line_color, fill);
	COLOR = vec4(col.rgb, col.a * outer);
}
