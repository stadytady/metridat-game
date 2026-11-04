// Lamplight in a window: an oil wick behind the shutter, not a steady bulb.
// Each window carries its own phase in the vertex alpha (MeshKit.color.a,
// set by Arch.house), so neighbours never pulse together. The flame breathes
// slowly, wavers faster and now and then gutters, going dimmer and redder.
// Stepped at 15 fps like the figures' motion, so it reads as PS1, not video.
shader_type spatial;
render_mode unshaded, cull_disabled;

global uniform vec2 psx_resolution;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
// the colour the flame sinks to when it gutters
uniform vec4 low : source_color = vec4(0.75, 0.32, 0.1, 1.0);

varying float phase;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

// smooth 1D value noise in [0, 1]
float noise(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

void vertex() {
	UV *= uv_scale;
	phase = COLOR.a * 97.0;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = psx_resolution * 0.5;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
}

void fragment() {
	float t = floor(TIME * 15.0) / 15.0;
	float breathe = noise(t * 0.7 + phase);
	float waver = noise(t * 5.3 + phase * 1.7);
	// a draught: rare, short dips
	float gutter = smoothstep(0.82, 0.97, noise(t * 1.9 + phase * 3.1));
	// some lamps are trimmed lower than others
	float wick = 0.8 + 0.2 * hash(phase);
	float b = clamp(wick * (0.62 + 0.26 * breathe + 0.12 * waver - 0.35 * gutter), 0.0, 1.0);
	b = floor(b * 12.0 + 0.5) / 12.0;
	vec3 flame = mix(low.rgb, tint.rgb, b);
	ALBEDO = texture(albedo_tex, UV).rgb * flame * b * COLOR.rgb;
}
