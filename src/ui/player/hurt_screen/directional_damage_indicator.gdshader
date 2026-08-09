shader_type canvas_item;

uniform vec4 segment_color : source_color = vec4(1.0, 0.4, 0.4, 1.0);
uniform vec4 background_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float outer_radius : hint_range(0.0, 0.5) = 0.4;
uniform float thickness : hint_range(0.0, 0.5) = 0.1;
uniform float taper : hint_range(0.0, 0.5) = 0.05;

// Damage indicator
uniform int active_arcs_count : hint_range(0, 16) = 3;
uniform float start_angles_degrees[16];
uniform float arc_spans_degrees[16];
uniform float arc_alpha[16];
// Ring at base of indicator
uniform float arc_ring_span : hint_range(0.0, 180.0) = 6.0;
uniform float arc_ring_thickness : hint_range(0.0, 0.2) = 0.03;
uniform float arc_ring_gap : hint_range(0.0, 0.1) = 0.01;


float normalize_angle(float a) {
    a = mod(a, 2.0 * PI);
    if (a < 0.0) {
        a += 2.0 * PI;
    }
    return a;
}

// Returns 1.0 if angle lies within [start_rad, start_rad + span_rad], handling wrap past 2*PI.
float arc_contains(float angle, float start_rad, float span_rad) {
    float end_rad = start_rad + span_rad;
    if (end_rad > 2.0 * PI) {
        float wrapped_end = end_rad - 2.0 * PI;
        return clamp(step(start_rad, angle) + step(angle, wrapped_end), 0.0, 1.0);
    } else {
        return step(start_rad, angle) * step(angle, end_rad);
    }
}

void fragment() {
    vec2 pos = UV - vec2(0.5);
    float dist = length(pos);

    float inner_radius = outer_radius - thickness;
    float indicator_outer_radius = inner_radius - arc_ring_gap;
    float indicator_inner_radius = indicator_outer_radius - arc_ring_thickness;

    float main_ring_mask = step(dist, outer_radius) * step(inner_radius, dist);
    float indicator_ring_mask = step(dist, indicator_outer_radius) * step(indicator_inner_radius, dist);

    float angle = atan(pos.y, pos.x);
    if (angle < 0.0) {
        angle += 2.0 * PI;
    }
	
	float main_taper_t = clamp((dist - inner_radius) / max(taper, 0.0001), 0.0, 1.0);
	
	float main_uncovered = 1.0;
	float indicator_uncovered = 1.0;

    for (int i = 0; i < 16; i++) {
		if (arc_spans_degrees[i] == 0.0) {
			continue;
		}
		
        float start_rad = radians(start_angles_degrees[i]);
		float span_rad = radians(arc_spans_degrees[i]);
		float mid_rad = normalize_angle(start_rad + span_rad * 0.5);
		float this_alpha = clamp(arc_alpha[i], 0.0, 1.0);
		
		float tapered_main_span_rad = span_rad * (1.0 - main_taper_t);

		if (main_ring_mask > 0.0) {
		    float tapered_start_rad = normalize_angle(mid_rad - tapered_main_span_rad * 0.5);
			float hit = arc_contains(angle, tapered_start_rad, tapered_main_span_rad);
			if (hit > 0.0) {
				main_uncovered *= (1.0 - this_alpha);
			}
        }

		if (indicator_ring_mask > 0.0) {
		    float indicator_start_rad = normalize_angle(mid_rad - radians(arc_ring_span) * 0.5);
			float hit = arc_contains(angle, indicator_start_rad, radians(arc_ring_span));
			if (hit > 0.0) {
                indicator_uncovered *= (1.0 - this_alpha);
			}
        }
    }
	
	float main_alpha = 1.0 - main_uncovered;
	float indicator_alpha = 1.0 - indicator_uncovered;

    float final_mask = clamp(
		main_ring_mask * main_alpha + indicator_ring_mask * indicator_alpha,
		0.0, 1.0
	);
	
    COLOR = mix(background_color, segment_color, final_mask);
}