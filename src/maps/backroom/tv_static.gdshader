shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform float texture_scale : hint_range(0.01, 10.0) = 1.0;
uniform vec2 global_offset = vec2(0.0, 0.0);
uniform vec3 emission_color : source_color;
uniform float emission_intensity : hint_range(0.0, 20.0) = 1.0;

// A basic hash function to generate random floats from 0 to 1
float hash(vec2 p) {
    return fract(1.0e4 * sin(17.0 * p.x + 0.1 * p.y) * (0.1 + abs(sin(13.0 * p.y + p.x))));
}

void fragment() {
	vec2 random_shift = vec2(
		hash(vec2(TIME, 10.0)),
		hash(vec2(TIME, 20.0))
	);
	vec2 offset = global_offset + random_shift;

    // Calculate world-space position and normals
    vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 world_normal = normalize(INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;

    // Project textures based on normals
    vec3 blend_weights = abs(world_normal);
    blend_weights = normalize(max(blend_weights, vec2(0.0001, 0.0001).xxy)); // Prevent division by zero

    // Sample each axis using world position + offset
    vec3 col_x = texture(albedo_texture, world_pos.zy * texture_scale + offset).rgb;
    vec3 col_y = texture(albedo_texture, world_pos.xz * texture_scale + offset).rgb;
    vec3 col_z = texture(albedo_texture, world_pos.xy * texture_scale + offset).rgb;

    // Blend the samples based on the angle of the mesh
    vec3 final_color = col_x * blend_weights.x + col_y * blend_weights.y + col_z * blend_weights.z;

    ALBEDO = final_color;
	EMISSION = ALBEDO * emission_color * emission_intensity;
}
