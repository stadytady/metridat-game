// psx_lit with a 1-bit alpha cut-out, both faces drawn: nets, thin cloth.
// Alpha-tested, not blended, so it stays in the opaque pass (no sorting,
// same look in Forward+ and Compatibility).
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

global uniform vec2 psx_resolution;
global uniform float psx_affine;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform float affine_amount : hint_range(0.0, 1.0) = 1.0;

varying vec3 affine_uv;

void vertex() {
	UV *= uv_scale;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = psx_resolution * 0.5;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
	affine_uv = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec2 uv = mix(UV, affine_uv.xy / affine_uv.z, psx_affine * affine_amount);
	vec4 c = texture(albedo_tex, uv) * tint;
	ALBEDO = c.rgb * COLOR.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
