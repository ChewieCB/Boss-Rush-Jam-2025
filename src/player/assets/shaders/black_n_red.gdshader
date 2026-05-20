shader_type canvas_item;

uniform float red_intensity    : hint_range(0.0, 1.0) = 0.5;
uniform float black_threshold  : hint_range(0.0, 1.0) = 0.5;
uniform float contrast         : hint_range(0.5, 4.0) = 1.8;

// When true, every pixel is snapped to pure red or pure black — no in-between
uniform bool  posterize = false;

// Threshold used for the posterize snap (0.5 = equal split)
uniform float posterize_threshold : hint_range(0.0, 1.0) = 0.5;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec4 screen = texture(SCREEN_TEXTURE, SCREEN_UV);

    float lum = dot(screen.rgb, vec3(0.299, 0.587, 0.114));
    lum = pow(clamp(lum, 0.0, 1.0), 1.0 / contrast);
    lum = smoothstep(black_threshold, black_threshold + 0.2, lum);

    if (posterize) {
        // Hard snap: above threshold → full red, below → pure black
        lum = step(posterize_threshold, lum);
    }

    COLOR = vec4(lum * red_intensity, 0.0, 0.0, 1.0);
}