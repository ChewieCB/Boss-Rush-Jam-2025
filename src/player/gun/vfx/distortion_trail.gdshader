shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise_texture : hint_normal, repeat_enable;
uniform float distortion_strength : hint_range(0.0, 0.05) = 0.015;
uniform float trail_opacity : hint_range(0.0, 1.0) = 0.6;
uniform float time_offset = 0.0;

void fragment() {
    vec2 uv = UV;

    // Sample animated noise for distortion
    vec2 noise_uv = uv + vec2(TIME * 0.3 + time_offset, TIME * 0.15);
    vec3 noise = texture(noise_texture, noise_uv * 2.0).rgb;
    vec2 offset = (noise.rg - 0.5) * distortion_strength;

    // Fade distortion toward the tail (UV.x = 0 is tail, 1 is head)
    float trail_fade = uv.x;
    offset *= trail_fade;

    // Sample the screen behind with offset
    vec2 screen_uv = SCREEN_UV + offset;
    vec3 distorted = texture(SCREEN_TEXTURE, screen_uv).rgb;

    // Add a heat-shimmer color tint (slight warm shift)
    distorted += vec3(0.05, 0.02, -0.02) * trail_fade;

    ALBEDO = distorted;
    ALPHA = trail_fade * trail_opacity;
}