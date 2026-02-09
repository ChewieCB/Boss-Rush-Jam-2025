shader_type canvas_item;
uniform float skew_factor = 0.0; // Adjust this value

void vertex() {
    VERTEX.x -= skew_factor * VERTEX.y; // Skews the bar
}
