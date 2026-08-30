shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque, diffuse_burley;

uniform sampler2D texture_base : source_color, hint_default_white;   // static base layer
uniform sampler2D texture_overlay : source_color, hint_default_white; // second texture, tinted/masked by the effect
uniform float radius = 1.0;
uniform float speed : hint_range(0.0, 10.0) = 1.0;
uniform vec4 effect_color : source_color = vec4(0.251, 0.0, 0.0, 1.0);
uniform float overlay_amount : hint_range(0.0, 1.0) = 1.0; // how much the effect shows, 0 = hidden, 1 = fully shown
uniform float edge_width : hint_range(0.0, 1.0) = 0.1;
uniform float emission_strength : hint_range(0.0, 10.0) = 3.0;
uniform float overlay_opacity : hint_range(0.0, 1.0) = 1.0; // max opacity of the overlay layer where active

float snoise(vec3 uv, float res)
{
    const vec3 s = vec3(1e0, 1e2, 1e3);
    uv *= res;

    vec3 uv0 = floor(mod(uv, res)) * s;
    vec3 uv1 = floor(mod(uv + vec3(1.0), res)) * s;

    vec3 f = fract(uv);
    f = f * f * (3.0 - 2.0 * f);
    vec4 v = vec4(uv0.x + uv0.y + uv0.z, uv1.x + uv0.y + uv0.z,
                  uv0.x + uv1.y + uv0.z, uv1.x + uv1.y + uv0.z);
    vec4 r = fract(sin(v * 1e-1) * 1e3);
    float r0 = mix(mix(r.x, r.y, f.x), mix(r.z, r.w, f.x), f.y);
    r = fract(sin((v + uv1.z - uv0.z) * 1e-1) * 1e3);
    float r1 = mix(mix(r.x, r.y, f.x), mix(r.z, r.w, f.x), f.y);

    return mix(r0, r1, f.z) * 2.0 - 1.0;
}

void fragment()
{
    vec2 p = (UV - 0.5) * radius;

    float color = 3.0 - (3.0 * length(2.0 * p));

    vec3 coord = vec3(atan(p.x, p.y) / 6.2832 + 0.5, length(p) * 0.4, 0.5);

    float time = -TIME / speed;
    for (int i = 1; i <= 7; i++)
    {
        float power = pow(2.0, float(i));
        color += (1.5 / power) * snoise(coord + vec3(0.0, -time * 0.05, time * 0.01), power * 16.0);
    }

    vec4 base = texture(texture_base, UV);
    vec4 overlay_tex = texture(texture_overlay, UV);

    // Threshold controlling how much of the noise pattern is "active" as overlay
    float threshold = mix(2.0, -1.0, overlay_amount);
    float mask = smoothstep(threshold, threshold + edge_width, color);

    // Tint the overlay texture with effect_color, same coloring math as before
    vec3 edge_color = vec3(
        color - (1.0 - effect_color.r),
        color - (1.0 - effect_color.g),
        color - (1.0 - effect_color.b)
    );

    vec3 overlay_color = overlay_tex.rgb * edge_color;
    float overlay_alpha = overlay_tex.a * mask * overlay_opacity;

    // Composite overlay on top of the always-visible base
    ALBEDO = mix(base.rgb, overlay_color, overlay_alpha);
    ALPHA = base.a; // base stays fully opaque/visible regardless of overlay

    // Emissive glow riding along the overlay's edge
    float rim = 1.0 - smoothstep(0.0, edge_width, abs(color - threshold));
    EMISSION = edge_color * rim * mask * emission_strength;
}