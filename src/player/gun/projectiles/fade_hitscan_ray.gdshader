shader_type spatial;

// This shader make object fade away from the origin position

uniform vec3 origin_position;
uniform float fade_distance;
uniform float fade_multiplier = 1;

varying vec3 world_vertex;

uniform vec4 color : source_color = vec4(0.94, 0.54, 0.15, 1.0);
uniform float taper_amount : hint_range(-2.0, 2.0);

void vertex() {
    // Calculate the taper factor based on the local z-position
    float taper_factor = VERTEX.z * taper_amount;

    // Apply the taper to the x and y axes
    VERTEX.x *= 1.0 + taper_factor;
    VERTEX.y *= 1.0 + taper_factor;
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
// Calculate the distance between the fragment and the origin
	float origin_distance = length(origin_position - world_vertex);
    
// Calculate the alpha value based on the distance
	float alpha = smoothstep(0.0, fade_distance, origin_distance);
	ALBEDO = color.rgb;
	ALPHA = alpha * fade_multiplier;
// Discard the fragment if the alpha is zero
	if (alpha <= 0.0) {
		discard;
	}
}