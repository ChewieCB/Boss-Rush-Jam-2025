shader_type spatial;
render_mode shadows_disabled;

uniform sampler3D noise_tex : source_color;

uniform float spike_strength = 0.6;
uniform float noise_scale = 1.5;
uniform float time_speed = 1.0;

uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);      
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

varying float v_noise_val;

void vertex() {
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

    // Sample animated noise from 3D texture
    vec3 noise_coord = world_pos * noise_scale + vec3(0.0, 0.0, TIME * time_speed);
    float noise_val = texture(noise_tex, noise_coord).r;

    // Displace along the normal direction
    VERTEX += NORMAL * (noise_val * spike_strength);

    // Pass noise value to fragment shader
    v_noise_val = noise_val;
}

void fragment() {
    // Interpolate color based on the noise value
    ALBEDO = mix(base_color.rgb, highlight_color.rgb, v_noise_val);

    // Optional: add glow to slimy spikes
    EMISSION = ALBEDO * v_noise_val * 0.5;
}
