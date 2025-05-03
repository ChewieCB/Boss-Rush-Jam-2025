/*
	放射状ブラーエフェクト by あるる（きのもと　結衣） @arlez80
	Radial Blur Effect by Yui Kinomoto

	MIT License
*/
shader_type canvas_item;

// 発射中央部
uniform vec2 blur_center = vec2( 0.5, 0.5 );
// ブラー強度
uniform float blur_power : hint_range( 0.0, 1.0 ) = 0.01;
uniform float warp_speed = 1.0;
// サンプリング回数
uniform int sampling_count : hint_range( 1, 64 ) = 6;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment( )
{
	vec2 direction = SCREEN_UV - blur_center;
	vec3 c = vec3( 0.0, 0.0, 0.0 );
	float f = 1.0 / float( sampling_count );
	for( int i=0; i < sampling_count; i++ ) {
		c += texture( SCREEN_TEXTURE, SCREEN_UV - blur_power * direction * float(i) ).rgb * f;
	}
	
	// TWEAK THE COEFFS AND/OR EQUATION FOR A DIFFERENT WARP PATTERN
	c.x += sin(c.y * 1.54 * PI + TIME) * cos(c.y * 1.31 * PI + TIME) * 0.1 * warp_speed;
	c.y += cos(c.x * 1.74 * PI + TIME) * -sin(c.y * 1.64 * PI + TIME) * 0.1 * warp_speed;
	
	COLOR.rgb = c;

	//ALBEDO = color.xyz;
	//ALPHA = color.a;
	
}