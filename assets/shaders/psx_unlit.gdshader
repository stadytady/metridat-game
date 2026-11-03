// Flat emissive PS1 surface (markers, fire). Fog still applies.
shader_type spatial;
render_mode unshaded, cull_disabled;

global uniform vec2 psx_resolution;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);

void vertex() {
	UV *= uv_scale;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = psx_resolution * 0.5;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * tint * COLOR;
	ALBEDO = c.rgb;
}
