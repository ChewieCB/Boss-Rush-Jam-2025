shader_type spatial;
render_mode unshaded;

uniform bool warp_ScreenSpace = false;
uniform sampler2D texture_albedo : source_color, filter_nearest;
uniform float uv_scale = 1.0;
uniform float warp_speed = 1.0;

void fragment() {
	vec2 uv = vec2(0.0);

	if(warp_ScreenSpace){
		uv = SCREEN_UV;
	}else{
		uv = UV;
	}

	// TODO: ADD NOISE SAMPLER INSTEAD OF USING TRIG?

	// TWEAK THE COEFFS AND/OR EQUATION FOR A DIFFERENT WARP PATTERN
	uv.x += sin(uv.y * 1.54 * PI + TIME) * cos(uv.y * 1.31 * PI + TIME) * 0.1 * warp_speed;
	uv.y += cos(uv.x * 1.74 * PI + TIME) * -sin(uv.y * 1.64 * PI + TIME) * 0.1 * warp_speed;

	vec4 color = texture(texture_albedo, uv * 2.0 * uv_scale);

	ALBEDO = color.xyz;
	ALPHA = color.a;
}
