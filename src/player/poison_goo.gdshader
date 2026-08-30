shader_type spatial;
render_mode unshaded;

uniform sampler2D tex : source_color;
uniform float tex_alpha = 1.0;
uniform float wave_amplitude : hint_range(0.0, 1.0) = 0.1;
uniform float wave_frequency : hint_range(0.0, 20.0) = 10.0;
uniform float wave_speed : hint_range(0.0, 10.0) = 1.0;
uniform bool vertical_wobble = true;

void fragment() {
    vec2 uv = UV;
    float wave = sin((vertical_wobble ? uv.x : uv.y) * wave_frequency + TIME * wave_speed) * wave_amplitude;

    if (vertical_wobble) {
        uv.y += wave;
    } else {
        uv.x += wave;
    }

    // Clamp the UVs to prevent texture wrapping
    uv = clamp(uv, vec2(0.0), vec2(1.0));
    vec4 tex_color = texture(tex, uv);
    ALBEDO = tex_color.rgb;
    ALPHA = tex_color.a * tex_alpha;
}