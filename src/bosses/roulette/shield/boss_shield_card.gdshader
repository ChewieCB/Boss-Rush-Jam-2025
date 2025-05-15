shader_type spatial;
render_mode blend_mix, depth_draw_never, unshaded, cull_back;

uniform sampler2D base_texture : source_color;
uniform float base_texture_alpha : hint_range(0.0, 1.0) = 1.0;
uniform vec2 uv_scale;
uniform sampler2D dissolve_texture : source_color;
uniform float dissolve_value : hint_range(0.0, 1.0) = 0.0;
uniform float burn_size : hint_range(0.0, 1.0) = 0.1;
uniform vec4 burn_color : source_color = vec4(1.0, 0.4, 0.0, 1.0); // glowing edge

void fragment() {
    vec2 uv = UV;
    float noise_val = texture(dissolve_texture, uv).r;

	// Avoid glowing border at dissolve start/end
    float burn_size_step = burn_size * step(0.001, dissolve_value) * step(dissolve_value, 0.999);

    // Burn falloff
    float inner = smoothstep(noise_val - burn_size_step, noise_val, dissolve_value);
    float border = smoothstep(noise_val, noise_val + burn_size_step, dissolve_value);

	vec3 base_color = texture(base_texture, uv * uv_scale).rgb;

    // Burned areas (threshold ≈ 0) should be fully transparent
    // Border area is glowing, rest is fully transparent
    ALBEDO = base_color * (1.0 - border);
    ALPHA = (1.0 - inner) * base_texture_alpha;
    EMISSION = base_color * (1.0 - border) * 2.0; // Optional glow
}