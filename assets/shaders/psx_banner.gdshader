// PS1-style hanging cloth: the lit PS1 surface, tied along its top edge and free
// below, so the wind takes the hem out and a ripple runs along it. It moves along
// the cloth's own local z, not its normal: the cloth is two faces back to back,
// and pushing each along its own normal would pull them apart. The offset is
// never negative, so the cloth never swings back into whatever it hangs from.
// UV: x 0..1 along the top edge, y 0 at the tied edge to 1 at the hem.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

global uniform vec2 psx_resolution;
global uniform float psx_affine;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform float affine_amount : hint_range(0.0, 1.0) = 1.0;
// How far the hem blows out, in metres, how big the ripple along it, how fast.
uniform float swell : hint_range(0.0, 0.8) = 0.32;
uniform float ripple : hint_range(0.0, 0.2) = 0.04;
uniform float speed : hint_range(0.0, 4.0) = 1.3;

varying vec3 affine_uv;

// Keep in step with Agora.banner_offset(): the test checks that one.
float offset(vec2 uv, float t) {
	float hang = pow(clamp(uv.y, 0.0, 1.0), 1.3);
	float gust = 0.6 + 0.4 * sin(t * speed + uv.x * 2.5);
	return hang * (swell * gust + ripple * sin(uv.x * 8.0 + t * speed * 2.1));
}

void vertex() {
	vec2 cloth = UV;
	UV *= uv_scale;
	vec3 v = VERTEX + vec3(0.0, 0.0, offset(cloth, TIME));
	VERTEX = v;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(v, 1.0);
	vec2 grid = psx_resolution * 0.5;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
	affine_uv = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec2 uv = mix(UV, affine_uv.xy / affine_uv.z, psx_affine * affine_amount);
	vec4 c = texture(albedo_tex, uv) * tint;
	ALBEDO = c.rgb * COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
