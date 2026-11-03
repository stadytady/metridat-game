// PS1 sea: unlit (a flat sea in low sun reads as dark mud with Lambert),
// coarse vertex swell, world-space scrolling texture, snapped vertices.
shader_type spatial;
render_mode unshaded, cull_back;

global uniform vec2 psx_resolution;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform float texel_meters = 6.0;
uniform float swell = 0.35;
uniform float brightness = 0.9;

varying vec2 world_xz;
varying float crest;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = sin(w.x * 0.05 + TIME * 0.6) * 0.6 + sin(w.z * 0.07 - TIME * 0.45) * 0.4;
	VERTEX.y += h * swell;
	crest = h;
	world_xz = w.xz;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = psx_resolution * 0.5;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
}

void fragment() {
	vec2 uv = world_xz / texel_meters * uv_scale;
	vec4 a = texture(albedo_tex, uv + vec2(TIME * 0.010, TIME * 0.004));
	vec4 b = texture(albedo_tex, uv * 0.5 - vec2(TIME * 0.006, -TIME * 0.008));
	vec3 c = mix(a.rgb, b.rgb, 0.5) * tint.rgb * brightness;
	c += vec3(0.05, 0.035, 0.02) * clamp(crest, 0.0, 1.0);
	ALBEDO = c;
}
