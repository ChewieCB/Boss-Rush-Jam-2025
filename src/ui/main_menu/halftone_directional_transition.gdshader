// Original : Shader By Zacksly - https://zacksly.itch.io/
shader_type canvas_item;
uniform bool transparent_dots;
uniform float AspectRatio = 1.5;
uniform float Dots = 10.0;
uniform float _min;
uniform float _max = 1.0;
uniform float transition_angle = 0.0;

uniform float height = 0.0;

uniform float scroll_speed : hint_range(0, 2) = 0.08;
uniform float angle_degrees : hint_range(0, 360) = 45.0;
uniform float repeat_x : hint_range(1, 20) = 20;
uniform float repeat_y : hint_range(1, 20) = 12;
uniform float row_offset : hint_range(0, 1) = 1;
uniform sampler2D texture_to_scroll;

void fragment() {
	// Rotate the dot grid
	float dots_angle_rad = radians(transition_angle);
	mat2 dots_rot = mat2(
		vec2(cos(dots_angle_rad), -sin(dots_angle_rad)),
		vec2(sin(dots_angle_rad),  cos(dots_angle_rad))
	);
	vec2 scaled_uv = UV * vec2(AspectRatio * Dots, Dots);
	vec2 rotated_uv = dots_rot * scaled_uv;
	vec3 uv_grid = fract(vec3(rotated_uv, 0.0));

	float grid = distance(uv_grid, vec3(0.5, 0.5, 0.5));

	// Apply rotated wipe direction for animated transition
	vec2 wipe_dir = vec2(cos(dots_angle_rad), sin(dots_angle_rad));
	float wipe_value = dot(UV, wipe_dir);  // This replaces UV.y
	vec3 raw_cam_image = vec3(1,1,1) * (wipe_value + height);

	vec3 grayscale;
	{
		float max1 = max(raw_cam_image.r, raw_cam_image.g);
		float max2 = max(max1, raw_cam_image.b);
		float max3 = max(max1, max2);
		grayscale = vec3(max3, max3, max3);
	}

	vec3 clamped = clamp(grayscale, vec3(_min), vec3(_max));

	bool black_dot_grid = grid > dot(vec3(1.0, 1.0, 1.0) - clamped, vec3(0.333333, 0.333333, 0.333333));
	bool white_dot_grid = grid < dot(clamped, vec3(0.333333, 0.333333, 0.333333));

	// Scrolling texture shader code
	float angle_rad = radians(angle_degrees);
	vec2 direction = vec2(cos(angle_rad), sin(angle_rad));
	vec2 offset_uv = UV - (TIME * scroll_speed * direction);
	float offset = fract(floor(offset_uv.y * repeat_y) * 0.5) > 0.0 ? (row_offset * 0.324) : 0.0;
	offset_uv.x += offset;
	vec2 scaled_uv_tex = vec2(fract(offset_uv.x * repeat_x),
	            fract(offset_uv.y * repeat_y));
	vec2 texelSize = vec2(1.0) / vec2(textureSize(texture_to_scroll, 0));
	vec2 snappedUV = round(scaled_uv_tex / texelSize) * texelSize;

	vec4 texture_uv = texture(texture_to_scroll, snappedUV);

	vec4 grid_result = transparent_dots? (black_dot_grid? texture_uv : vec4(0.0)): (white_dot_grid? texture_uv : vec4(0.0));

	COLOR.rgb = grid_result.rgb;

	COLOR.a = grid_result.a;
}