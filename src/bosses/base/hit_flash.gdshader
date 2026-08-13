shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, depth_prepass_alpha;
// Remove unshaded if you want shading
// Replace cull_disabled if you want to only show one side (cull_front, cull_back)
// Reference for depth ::: https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html#render-modes

uniform bool active = false; // Sets pixels to flash color when true
uniform vec4 flash_color: source_color = vec4(1.0,1.0,1.0,1.0); // The color to use when active
uniform bool y_billboard = false; // Enables Y-Billboarding when true
uniform sampler2D tex: source_color; // A copy of the texture for the Sprite3D or AnimatedSprite3D
uniform float scale = 1.0;

void vertex() {
	VERTEX *= scale;
	// You can comment out this function if you don't need billboarding
	if (y_billboard == true) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
	}
	else {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	}
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 col = texture(tex, UV);
	vec4 set_col = col;
	if(active == true) {
		set_col = flash_color;
	}
	ALBEDO = vec3(set_col.r,set_col.g,set_col.b);
	ALPHA = col.a;
}