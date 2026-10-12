shader_type canvas_item;
uniform float animation_time = 0.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
 vec2 p=UV*vec2(4.0,3.0)+vec2(animation_time*0.025,0.0);
 float mist=noise(p)*0.6+noise(p*2.1)*0.3+noise(p*4.3)*0.1;
 float edge=smoothstep(0.0,0.20,UV.x)*smoothstep(0.0,0.20,1.0-UV.x)*smoothstep(0.0,0.20,UV.y)*smoothstep(0.0,0.20,1.0-UV.y);
 COLOR=vec4(mix(vec3(0.14,0.19,0.21),vec3(0.48,0.53,0.52),mist),edge*0.97);
}
