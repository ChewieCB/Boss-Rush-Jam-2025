shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform sampler2D sprite_texture : source_color;
uniform bool enable_billboard = true;

uniform float hit_effect : hint_range(0,1) = 0.0;
uniform float shake_intensity = 0.02;
uniform float flash_speed = 30.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
    if (hit_effect > 0.0) {
        float time = TIME * 30.0;

        vec2 random_offset = vec2(
            rand(vec2(time, 0.0)) * 2.0 - 1.0,
            rand(vec2(time, 10.0)) * 2.0 - 1.0
        );

        VERTEX.xy += random_offset * shake_intensity * hit_effect;
    }
}

void fragment() {
    vec4 original_color = texture(sprite_texture, UV);

    if (hit_effect > 0.0) {
        float flash = sin(TIME * flash_speed) * 0.5 + 0.5;
        flash *= original_color.a;

        vec4 final_color = mix(original_color, flash_color, flash);
        final_color = mix(original_color, final_color, hit_effect);
        final_color.a = original_color.a;

        ALBEDO = final_color.rgb;
        ALPHA  = final_color.a;
    } else {
        ALBEDO = original_color.rgb;
        ALPHA  = original_color.a;
    }
}
