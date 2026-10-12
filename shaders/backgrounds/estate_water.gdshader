shader_type canvas_item;
uniform bool feather_edges = false;
uniform float animation_time = 0.0;
void fragment() {
 vec4 original = texture(TEXTURE,UV);
 float water = (1.0-smoothstep(0.09,0.16,UV.y))*step(original.r*1.12,original.b);
 vec2 ripple = vec2(sin(UV.y*240.0+animation_time*0.65),cos(UV.x*180.0+animation_time*0.5))*0.0007*water;
 COLOR = texture(TEXTURE,UV+ripple);
 if (feather_edges) {
 float edge=min(UV.x,1.0-UV.x);
 float rock=sin(UV.y*73.0)*0.004+sin(UV.y*157.0)*0.004;
 COLOR.a*=smoothstep(0.0,0.065,edge+rock);
 COLOR.a*=smoothstep(0.0,0.025,UV.y);
 }
}
