shader_type canvas_item;
render_mode blend_mix;
uniform sampler2D region_mask : source_color, filter_linear;
uniform float intensity : hint_range(0.0, 0.25) = 0.052;
void fragment() {
    float m=texture(region_mask,UV).r;
    float n=sin(UV.x*38.0+TIME*0.12+sin(UV.y*33.0)*2.0)*sin(UV.y*44.0-TIME*0.14);
    float alpha=m*intensity*smoothstep(-0.25,0.85,n);
    COLOR=vec4(vec3(0.67,0.77,0.83),alpha);
}
