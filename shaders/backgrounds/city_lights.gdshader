shader_type canvas_item;
render_mode blend_add;
uniform sampler2D region_mask : source_color, filter_linear;
uniform float intensity : hint_range(0.0, 0.8) = 0.11;
void fragment() {
    vec2 p=UV;
    float m=texture(region_mask,p).r;
    vec3 original=texture(TEXTURE,p).rgb;
    float warm=smoothstep(0.09,0.55,original.r-original.b);
    float bright=smoothstep(0.46,0.89,dot(original,vec3(0.3,0.58,0.12)));
    float pulse=0.72+0.13*sin(TIME*1.17+p.x*75.0)+0.15*sin(TIME*0.53+p.y*103.0);
    COLOR=vec4(vec3(1.0,0.7,0.35),m*warm*bright*pulse*intensity);
}
