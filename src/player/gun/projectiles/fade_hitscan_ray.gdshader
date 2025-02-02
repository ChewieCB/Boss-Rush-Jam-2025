shader_type spatial;

// This shader make object fade away from the origin position

// Enable the material transparent fade away from origin pos
uniform bool enable_fade;
// Enable the taper effect (one side is bigger while other side is smaller)
uniform bool enable_taper;

uniform vec3 origin_position;
uniform float fade_distance;
uniform float fade_multiplier = 1;

varying vec3 world_vertex;

uniform vec4 color : source_color = vec4(0.94, 0.54, 0.15, 1.0);
uniform float taper_amount : hint_range(-2.0, 2.0);

// Emission parameters
uniform vec3 emission_color : source_color = vec3(1.0, 0.5, 0.1);
uniform float emission_intensity : hint_range(0.0, 5.0) = 1.0;

void vertex() {
    // Calculate the taper factor based on the local z-position
    float taper_factor = VERTEX.z * taper_amount;
    // Apply the taper to the x and y axes
	if (enable_taper) {
	    VERTEX.x *= 1.0 + taper_factor;
	    VERTEX.y *= 1.0 + taper_factor;
	}
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Calculate the distance between the fragment and the origin
	float origin_distance = length(origin_position - world_vertex);

	// Calculate the alpha value based on the distance
	float alpha = 1.0;
	if (enable_fade) {
		alpha = smoothstep(0.0, fade_distance, origin_distance);
	}
	ALBEDO = color.rgb;
	ALPHA = alpha * fade_multiplier;
	// Discard the fragment if the alpha is zero
	if (alpha <= 0.0) {
		discard;
	}
    // Add emission effect
    EMISSION = emission_color * emission_intensity;
}