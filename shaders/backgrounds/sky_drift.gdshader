shader_type canvas_item;
render_mode blend_mix;
uniform sampler2D region_mask : source_color, filter_linear;
uniform float speed = 0.012;
uniform float intensity : hint_range(0.0, 0.3) = 0.085;
void fragment() {
    vec2 p = UV;
    float m = texture(region_mask,p).r;
    float t=TIME*speed;
    float wisps = sin((p.x - t)*43.0 + sin(p.y*35.0+t*4.0)*2.0);
    float bands = sin((p.x+t*0.3)*73.0+p.y*16.0);
    float density = smoothstep(0.35,0.95, 0.5 + 0.33*wisps + 0.13*bands);
    COLOR = vec4(vec3(0.87,0.69,0.66), m*density*intensity);
}
