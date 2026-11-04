// PS1 sea. Unlit (Lambert on a flat sea in low sun reads as mud), but every
// polygon gets a flat facet shade against the sun, so the swell shimmers in
// angular steps. Waves: a few directional sines with deep-water dispersion
// (long waves run faster), shoaling near the shore. Foam: whitecaps on crests
// and surf bands running in to the real waterline (shore_tex, sampled from the
// terrain). Foam edges are ordered-dithered like the rest of the frame.
shader_type spatial;
render_mode unshaded, cull_back;

global uniform vec2 psx_resolution;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform float texel_meters = 6.0;
uniform float amplitude = 1.0;
uniform float speed = 0.75;
// The sea's clock, advanced by sea.gd, so scripts can sample the same waves
// (Sea.height_at) and float ships on them.
uniform float sea_time = 0.0;
// A sheltered patch (the harbour by the pier): centre x, z, radius, how much calmer.
uniform vec4 calm = vec4(0.0, 0.0, 1.0, 0.0);
// R = waterline x for z in shore_z_range (see Topo.waterline_x)
uniform sampler2D shore_tex : filter_linear, repeat_disable;
uniform vec2 shore_z_range = vec2(-512.0, 512.0);
// Direction to the key light (sun, or moon at night) and the light colour of
// the hour: both come from DayCycle via global uniforms.
global uniform vec3 psx_key_dir;
global uniform vec3 psx_light_tint;
uniform vec4 foam_color : source_color = vec4(0.84, 0.86, 0.80, 1.0);
uniform vec4 crest_color : source_color = vec4(0.53, 0.66, 0.65, 1.0);

varying vec3 wpos;
varying float crest;
varying float shore_d;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float shore_x(float z) {
	float u = (z - shore_z_range.x) / (shore_z_range.y - shore_z_range.x);
	return texture(shore_tex, vec2(clamp(u, 0.0, 1.0), 0.5)).r;
}

// Sum of directional waves; returns height, writes the normalised crest (-1..1).
float waves(vec2 p, float t, float shoal, out float c) {
	const vec4 W[4] = vec4[](
		// dir.x, dir.y, wavelength, amplitude
		vec4(1.0, 0.25, 42.0, 0.55),
		vec4(0.75, -0.65, 24.0, 0.28),
		vec4(0.3, 1.0, 14.0, 0.16),
		vec4(1.0, -0.1, 8.0, 0.09));
	float h = 0.0;
	float total = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 d = normalize(W[i].xy);
		// shoaling: waves shorten and steepen in shallow water
		float len = W[i].z * mix(1.0, 0.6, shoal);
		float k = 6.2831 / len;
		float w = sqrt(9.8 * k) * speed;
		float a = W[i].w * mix(1.0, 1.7, shoal);
		// sharpen crests a little (PS1-friendly "choppy" profile)
		float s = sin(dot(d, p) * k - w * t + float(i) * 1.7);
		h += a * (s + 0.25 * s * abs(s));
		total += a * 1.25;
	}
	c = h / total;
	return h * amplitude;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	shore_d = w.x - shore_x(w.z);
	float shoal = 1.0 - smoothstep(0.0, 70.0, shore_d);
	float c;
	float h = waves(w.xz, sea_time, shoal, c);
	// calm the surface right at the waterline so it does not lap over the beach
	h *= smoothstep(-1.0, 6.0, shore_d);
	h *= 1.0 - calm.w * (1.0 - smoothstep(calm.z * 0.5, calm.z, distance(w.xz, calm.xy)));
	VERTEX.y += h;
	crest = c;
	wpos = w + vec3(0.0, h, 0.0);
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = psx_resolution * 0.5;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
}

void fragment() {
	vec2 uv = wpos.xz / texel_meters * uv_scale;
	vec4 a = texture(albedo_tex, uv + vec2(sea_time * 0.010, sea_time * 0.004));
	vec4 b = texture(albedo_tex, uv * 0.5 - vec2(sea_time * 0.006, -sea_time * 0.008));
	vec3 base = mix(a.rgb, b.rgb, 0.5) * tint.rgb;

	// flat facet normal from screen derivatives: one shade per polygon
	vec3 n = normalize(cross(dFdy(wpos), dFdx(wpos)));
	n *= sign(n.y);
	float lit = clamp(dot(n, normalize(psx_key_dir)), 0.0, 1.0);
	vec3 col = base * (0.62 + 0.75 * lit);
	col = mix(col, crest_color.rgb, smoothstep(0.35, 0.8, crest) * 0.6);

	// foam: whitecaps on high crests + surf bands running to the waterline
	float caps = smoothstep(0.62, 0.9, crest) * 0.8;
	float d = shore_d;
	float bands = sin(d * 0.55 + sea_time * 1.9 * speed + sin(wpos.z * 0.05) * 1.5);
	float surf = smoothstep(0.55, 0.95, bands) * (1.0 - smoothstep(4.0, 28.0, d)) * 0.85;
	float edge = (1.0 - smoothstep(0.0, 2.5, d + a.r * 1.5)) * 0.9;
	float foam = clamp(max(max(caps, surf), edge), 0.0, 1.0);
	ivec2 p = ivec2(FRAGCOORD.xy);
	float th = (BAYER[(p.y % 4) * 4 + (p.x % 4)] + 0.5) / 16.0;
	if (foam > th) {
		col = foam_color.rgb * mix(0.85, 1.05, lit);
	}
	ALBEDO = col * psx_light_tint;
}
