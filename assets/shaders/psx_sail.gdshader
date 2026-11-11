// PS1-style sail: the lit PS1 surface, with the canvas bellying out of its plane so
// the ship is not carrying a painted board. Pinned at the edges, widest in the
// middle, breathing slowly.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

global uniform vec2 psx_resolution;
global uniform float psx_affine;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform float affine_amount : hint_range(0.0, 1.0) = 1.0;
// Furled (1) the canvas is gathered up under the yard in a tight roll; set
// per ship (an anchored or moored ship has no use for her sail). Model space:
// the yard of Props.ship runs along z at this height and x.
instance uniform float furl : hint_range(0.0, 1.0) = 0.0;
uniform float yard_y = 10.15;
uniform float yard_x = 0.82;
// How far the canvas bellies out of the plane, in metres, and how fast it breathes.
uniform float swell : hint_range(0.0, 0.6) = 0.16;
uniform float speed : hint_range(0.0, 4.0) = 1.1;

varying vec3 affine_uv;

void vertex() {
	UV *= uv_scale;
	// strongest in the middle of the canvas, nothing at the bolt ropes
	float belly = sin(clamp(UV.x, 0.0, 1.0) * 3.14159) * sin(clamp(UV.y, 0.0, 1.0) * 3.14159);
	float breath = 0.65 + 0.35 * sin(TIME * speed + UV.x * 5.0);
	vec3 v = VERTEX + NORMAL * belly * swell * breath * (1.0 - furl);
	// gathered up: everything below the yard pulled into a roll 0.35 m deep under it
	v.y = mix(v.y, yard_y - (yard_y - v.y) * 0.06, furl);
	v.x = mix(v.x, yard_x + 0.12, furl);
	VERTEX = v;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(v, 1.0);
	vec2 grid = psx_resolution * 0.5;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
	// Interpolating uv*w and w perspective-correctly, then dividing, yields affine UVs.
	affine_uv = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec2 uv = mix(UV, affine_uv.xy / affine_uv.z, psx_affine * affine_amount);
	vec4 c = texture(albedo_tex, uv) * tint;
	ALBEDO = c.rgb * COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
