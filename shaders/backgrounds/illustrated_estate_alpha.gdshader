shader_type canvas_item;
render_mode blend_mix;
// Generated illustration has a near-black matte outside the island.
// Keep the black stone *inside* the island; only very dark outer matte fades.
uniform float black_cut : hint_range(0.0, 0.12) = 0.028;
void fragment() {
    vec4 c = texture(TEXTURE, UV);
    float m = max(c.r, max(c.g, c.b));
    c.a *= smoothstep(black_cut, black_cut + 0.035, m);
    COLOR = c;
}
