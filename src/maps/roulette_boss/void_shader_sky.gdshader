shader_type sky;

uniform sampler2D texture_albedo : source_color, filter_nearest, repeat_enable;
uniform float uv_scale = 1.0;
uniform float warp_speed = 1.0;

void sky() {
    // SKY_COORDS is in [-1,1], remap to [0,1]
    vec2 uv = SKY_COORDS * 0.5 + 0.5;

    // Apply warp effect
    uv.x += sin(uv.y * 1.54 * 2.0 * PI + TIME) * cos(uv.y * 1.31 * PI + TIME) * 0.1 * warp_speed;
    uv.y += cos(uv.x * 1.74 * 2.0 * PI + TIME) * -sin(uv.y * 1.64 * PI + TIME) * 0.1 * warp_speed;

    // Scale UVs and wrap — the key to seamless tiling
    uv *= uv_scale;

    vec4 sample = texture(texture_albedo, uv);

    COLOR = sample.rgb;
}
