shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled;

uniform vec3 ring_color: source_color = vec3(1.0);
uniform float ring_frequency = 50.0;
uniform float ring_portion: hint_range(-0.9, 0.9, 0.1) = 0.0;
uniform float move_speed = -10.0;
uniform bool smooth_edge = false;

uniform float axis_start = -1.0;  // Local coordinate where the mesh starts
uniform float axis_end = 1.0;  // Local coordinate where the mesh ends
uniform float travel_progress : hint_range(0.0, 1.0) = 0.0; 
uniform float fade_width = 0.2;
uniform int fade_axis : hint_range(0, 2) = 1; // 0 = X, 1 = Y, 2 = Z

varying float local_axis_pos;

void vertex() {
	if (fade_axis == 0) {
		local_axis_pos = VERTEX.x;
	} else if (fade_axis == 1) {
		local_axis_pos = VERTEX.y;
	} else {
		local_axis_pos = VERTEX.z;
	}
}

void fragment() {
	float dist = distance(UV, vec2(0.5,0.5));
	float rings = sin(dist * ring_frequency + (TIME * move_speed));
	rings = step(ring_portion, rings);
	float blend_alpha = smoothstep(0.5, 0.4, dist);
	
	// [0.0 to 0.5] Front edge moves from start to end
	float front_progress = clamp(travel_progress * 2.0, 0.0, 1.0);
	// [0.5 to 1.0] Back edge moves from start to end
	float back_progress = clamp((travel_progress - 0.5) * 2.0, 0.0, 1.0);
	
	float current_front = mix(axis_start, axis_end, front_progress);
	float current_back = mix(axis_start, axis_end, back_progress);
	
	float front_mask = 1.0 - smoothstep(current_front - fade_width, current_front, local_axis_pos);
	float back_mask = smoothstep(current_back - fade_width, current_back, local_axis_pos);
	float axis_mask = front_mask * back_mask;

	if (dist > 0.5 || rings < 1.0){
		ALPHA = 0.0;
	}
	else if (rings > 0.0){
		ALBEDO = ring_color;
		ALPHA = (smooth_edge ? blend_alpha : 1.0) * axis_mask;
	}
}
