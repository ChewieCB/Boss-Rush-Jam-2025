shader_type canvas_item;
uniform float skew_factor = 0.0; // Adjust this value
uniform float skew_cutoff = 1.0;

void vertex() {
	if (VERTEX.x < skew_cutoff) {
    	VERTEX.x -= skew_factor * VERTEX.y; // Skews the bar
	}
}
