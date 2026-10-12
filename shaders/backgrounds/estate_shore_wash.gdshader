shader_type canvas_item;
uniform float animation_time = 0.0;
float land(vec4 c) {
    return smoothstep(0.035,0.08,max(c.r,max(c.g,c.b)))*c.a;
}
void fragment() {
    vec2 step_uv = TEXTURE_PIXEL_SIZE*13.0;
    float center = land(texture(TEXTURE,UV));
    float near_land = 0.0;
    near_land += land(texture(TEXTURE,UV+vec2(step_uv.x,0.0)));
    near_land += land(texture(TEXTURE,UV-vec2(step_uv.x,0.0)));
    near_land += land(texture(TEXTURE,UV+vec2(0.0,step_uv.y)));
    near_land += land(texture(TEXTURE,UV-vec2(0.0,step_uv.y)));
    float surf = (1.0-center)*(near_land*0.25)*smoothstep(0.53,0.78,UV.y);
    float pulse = 0.5+0.5*sin(UV.x*45.0+UV.y*27.0+animation_time*0.65);
    COLOR = vec4(vec3(0.29,0.52,0.54),surf*(0.12+0.15*pulse));
}
