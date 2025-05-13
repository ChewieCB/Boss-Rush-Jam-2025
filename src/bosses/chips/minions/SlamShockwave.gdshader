shader_type spatial;


uniform sampler2D base_texture;
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform float uv_fade_width : hint_range(0.01, 1.0) = 0.2;
uniform float uv_fade_position : hint_range(-2.0, 2.0) = 0.0; // animatable

uniform float arc_start_deg : hint_range(0, 360) = 0.0;
uniform float arc_end_deg : hint_range(0, 360) = 90.0;

varying vec3 local_pos;

vec2 rotate_uv(vec2 uv, float angle_rad) {
    uv -= vec2(0.5);
    float cos_a = cos(angle_rad);
    float sin_a = sin(angle_rad);
    uv = mat2(vec2(cos_a, -sin_a), vec2(sin_a, cos_a)) * uv;
    return uv + vec2(0.5);
}

void vertex() {
    local_pos = VERTEX;
}

void fragment() {
    // Compute angle in XZ plane
    float angle = degrees(atan(local_pos.z, local_pos.x));
    if (angle < 0.0) {
        angle += 360.0;
    }

    // Check if inside arc
    bool in_arc = false;
    if (arc_start_deg < arc_end_deg) {
        in_arc = angle >= arc_start_deg && angle <= arc_end_deg;
    } else {
        in_arc = angle >= arc_start_deg || angle <= arc_end_deg;
    }

    if (!in_arc) {
        discard;
    }

    // Rotate UV so that texture always faces the same direction
    //float arc_center_deg = mod((arc_start_deg + arc_end_deg) * 0.5, 360.0);
    //float rotation_rad = radians(arc_center_deg);
    //vec2 rotated_uv = rotate_uv(UV, -rotation_rad); // negate to counter arc rotation

	float fade_alpha = smoothstep(uv_fade_position - uv_fade_width, uv_fade_position + uv_fade_width, UV.x);

    vec4 tex_color = texture(base_texture, UV * uv_scale);
    ALBEDO = tex_color.rgb;
    ALPHA = tex_color.a * fade_alpha;
}