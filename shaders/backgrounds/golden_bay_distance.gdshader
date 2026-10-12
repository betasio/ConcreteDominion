shader_type canvas_item;
render_mode blend_mix;
// One draw call. Animate open water and high clouds; architecture stays still.
uniform float animation_time = 0.0;
uniform float fade_start : hint_range(0.0, 1.0) = 0.90;
uniform float fade_end : hint_range(0.0, 1.0) = 1.0;
void fragment() {
    vec2 uv = UV;
    float water = smoothstep(0.57, 0.68, uv.y);
    float sky = 1.0 - smoothstep(0.10, 0.20, uv.y);
    float t = animation_time;
    vec2 ripple = vec2(sin(uv.y*260.0+t*0.65+sin(uv.x*38.0)),
                       cos(uv.x*72.0-uv.y*110.0+t*0.42));
    uv += ripple * vec2(0.0014,0.00045) * water;
    uv.x += sin(t*0.025+uv.y*9.0)*0.004*sky;
    vec4 base = texture(TEXTURE, clamp(uv,vec2(0.001),vec2(0.999)));
    float luminance = dot(base.rgb,vec3(0.2126,0.7152,0.0722));
    // Cooler, quieter distance lets the estate's warm lights lead the scene.
    base.rgb = mix(vec3(luminance),base.rgb,0.70)*vec3(0.76,0.84,0.96);
    float glint = pow(max(0.0,sin(UV.y*430.0+t*0.8+sin(UV.x*65.0+t*0.2))),10.0);
    base.rgb += vec3(0.09,0.12,0.15)*glint*water*smoothstep(0.15,0.7,luminance);
    float haze = exp(-pow((UV.y-0.32)*8.0,2.0))*0.12;
    base.rgb = mix(base.rgb,vec3(0.25,0.32,0.39),haze);
    base.a *= 1.0-smoothstep(fade_start,fade_end,UV.y);
    COLOR = base;
}
