shader_type canvas_item;
uniform bool feather_edges = false;
uniform float south_overlap = 0.0;
uniform float animation_time = 0.0;
void fragment() {
 vec4 original = texture(TEXTURE,UV);
 float water = (1.0-smoothstep(0.09,0.16,UV.y))*step(original.r*1.12,original.b);
 vec2 ripple = vec2(sin(UV.y*240.0+animation_time*0.65),cos(UV.x*180.0+animation_time*0.5))*0.0007*water;
 COLOR = texture(TEXTURE,UV+ripple);
 if (south_overlap > 0.0) {
 COLOR.a *= smoothstep(0.0,south_overlap,1.0-UV.y);
 }
 if (feather_edges) {
 float edge=min(UV.x,1.0-UV.x);
 float rock=sin(UV.y*73.0)*0.004+sin(UV.y*157.0)*0.004;
 float sea = step(original.r*1.35,original.b);
 COLOR.a*=mix(1.0,smoothstep(0.0,0.018,edge+rock*0.3),sea);
 COLOR.a*=smoothstep(0.0,0.025,UV.y);
 }
}
