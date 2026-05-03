shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float divide = 0.065;      
uniform float blur = 0.385;        
uniform float fade_width = 0.995;  

void fragment() {
    float left_fade_edge = fade_width;
    float right_fade_edge = 1.0 - fade_width;

    float leftFade = 1.0;
    float rightFade = 1.0;

    // Normalize to 0..1 within the fade width region
    if (UV.x < left_fade_edge) {
        float px = UV.x / fade_width;
        leftFade = smoothstep(divide, divide + blur, px);
    }

    if (UV.x > right_fade_edge) {
        float px = (1.0 - UV.x) / fade_width; // mirrored
        rightFade = smoothstep(divide, divide + blur, px);
    }
	
	COLOR = texture(TEXTURE, UV);
    COLOR.a *= min(leftFade, rightFade);
}
