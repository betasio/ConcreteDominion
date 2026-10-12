shader_type canvas_item;
render_mode blend_mix;
// World-anchored water: camera movement never slides or stretches the coastline.
uniform float animation_time = 0.0;
uniform bool backplate = true;
uniform bool use_estate_water = false;
uniform sampler2D estate_water_detail : source_color, filter_linear_mipmap;
varying vec2 world_position;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
    vec2 p = world_position;
    float t = animation_time;
    float swell = sin(p.x*0.018+p.y*0.049+t*0.46);
    float detail = sin(p.x*0.063-p.y*0.13-t*0.61+2.0*swell);
    vec3 ocean = vec3(0.018,0.112,0.148) + vec3(0.009,0.020,0.024)*swell + vec3(0.004,0.009,0.011)*detail;
    if (use_estate_water) {
        // Reuse the unobstructed northern water from the estate art so hue,
        // wave scale and lighting agree at the coastline. Mirroring avoids seams.
        vec2 flow = p/vec2(210.0,76.0)+vec2(t*0.006,0.0);
        flow += vec2(detail,swell)*0.009;
        vec2 tile = abs(mod(flow,2.0)-1.0);
        vec2 water_uv = vec2(0.003,0.003)+tile*vec2(0.175,0.042);
        ocean = texture(estate_water_detail,water_uv).rgb;
        ocean += vec3(0.004,0.009,0.012)*detail;
    }
    if (backplate) {
        vec2 uv = UV;
        // The coast ends above .34: architecture and rocks remain perfectly still.
        float water = smoothstep(0.34,0.40,uv.y);
        uv += vec2(swell*0.0009,detail*0.00035)*water;
        vec3 art = texture(TEXTURE,clamp(uv,vec2(0.001),vec2(0.999))).rgb;
        art += vec3(0.009,0.017,0.020)*detail*water;
        float edge = smoothstep(0.0,0.10,UV.x)*(1.0-smoothstep(0.90,1.0,UV.x));
        edge *= 1.0-smoothstep(0.78,1.0,UV.y);
        COLOR = vec4(mix(ocean,art,edge),1.0);
    } else {
        COLOR = vec4(ocean,1.0);
    }
}
