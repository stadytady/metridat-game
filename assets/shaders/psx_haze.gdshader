// Far silhouettes (opposite shore): unlit, drawn past the fog end, blended
// towards the haze color by hand so they read as distant land in the mist.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;

global uniform vec2 psx_resolution;

uniform vec4 land_color : source_color = vec4(0.45, 0.42, 0.36, 1.0);
uniform vec4 haze_color : source_color = vec4(0.85, 0.65, 0.45, 1.0);
uniform float haze : hint_range(0.0, 1.0) = 0.65;

varying float height;

void vertex() {
	height = VERTEX.y;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = psx_resolution * 0.5;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
}

void fragment() {
	// Ridges a bit darker than the foot, like aerial perspective in reverse sunlight.
	float k = haze - clamp(height / 120.0, 0.0, 0.15);
	ALBEDO = mix(land_color.rgb, haze_color.rgb, k);
}
