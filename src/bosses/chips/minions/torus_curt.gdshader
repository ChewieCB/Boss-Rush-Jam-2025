shader_type spatial;

render_mode depth_draw_opaque, cull_back;

uniform float arc_start_deg = 0.0;
uniform float arc_end_deg = 90.0;

varying vec3 local_pos;

uniform vec4 base_color : source_color;


void vertex() {
    local_pos = VERTEX;
}

void fragment() {
    float angle = degrees(atan(local_pos.z, local_pos.x)); // XZ plane
    if (angle < 0.0) {
        angle += 360.0;
    }

    bool in_arc = false;
    if (arc_start_deg < arc_end_deg) {
        in_arc = angle >= arc_start_deg && angle <= arc_end_deg;
    } else {
        // Wraps around 360 → 0
        in_arc = angle >= arc_start_deg || angle <= arc_end_deg;
    }

    if (!in_arc) {
        discard;
    }

    ALBEDO = base_color.rgb;
    ALPHA = base_color.a;
}