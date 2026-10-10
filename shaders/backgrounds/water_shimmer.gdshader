shader_type canvas_item;
render_mode blend_add;
uniform sampler2D region_mask : source_color, filter_linear;
uniform float speed = 0.55;
uniform float intensity : hint_range(0.0, 0.7) = 0.16;
void fragment() {
    vec2 p = UV;
    float mask = texture(region_mask, p).r;
    float t = TIME * speed;
    float wave = sin(p.y * 420.0 + p.x * 75.0 + t * 2.1 + sin(p.x * 33.0 + t) * 2.0);
    float chop = sin(p.y * 690.0 - p.x * 127.0 - t * 3.5);
    float glints = pow(max(0.0, 0.5 + 0.33 * wave + 0.24 * chop), 6.0);
    float bright = glints * mask * intensity;
    COLOR = vec4(vec3(0.65, 0.79, 0.91), bright);
}
