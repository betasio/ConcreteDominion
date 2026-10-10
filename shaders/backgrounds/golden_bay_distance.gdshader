shader_type canvas_item;
render_mode blend_mix;
// This artwork is a distant panorama only. Fade out the lower half before
// estate buildings to avoid baking decorative structures into playable turf.
uniform float fade_start : hint_range(0.0, 1.0) = 0.37;
uniform float fade_end : hint_range(0.0, 1.0) = 0.66;
uniform float shimmer_strength : hint_range(0.0, 0.3) = 0.065;
void fragment() {
    vec2 uv = UV;
    vec4 base = texture(TEXTURE, uv);
    float water_band = smoothstep(0.36, 0.49, uv.y) * (1.0 - smoothstep(0.57, 0.71, uv.y));
    float wave = sin(uv.y * 480.0 + TIME * 1.2 + sin(uv.x * 50.0 + TIME * 0.22) * 2.0);
    float sparkle = pow(max(0.0, wave), 8.0) * water_band * shimmer_strength;
    base.rgb += vec3(0.5, 0.62, 0.73) * sparkle;
    float haze = sin(uv.x * 27.0 - TIME * 0.035 + uv.y * 8.0);
    base.rgb += vec3(0.018, 0.014, 0.012) * haze * (1.0 - smoothstep(0.1, 0.44, uv.y));
    base.a *= 1.0 - smoothstep(fade_start, fade_end, uv.y);
    COLOR = base;
}
