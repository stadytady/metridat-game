// Final pass over the low-res 3D image: 15-bit color with 4x4 ordered dither,
// like the PS1 framebuffer. Applied in low-res pixel space, scaled sharp-bilinear.
shader_type canvas_item;

uniform float color_levels = 31.0;
uniform float dither_amount : hint_range(0.0, 1.0) = 0.8;
uniform bool enabled = true;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	// Sharp bilinear: inside a low-res pixel sample its centre (flat, like
	// nearest); across a seam blend over one screen pixel only. At a scale of
	// 1.5 nearest alone gives columns 1, 2, 1, 2 px wide; at an integer scale
	// this is exactly nearest. Needs the container's linear filter.
	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec2 px = UV * size;
	vec2 seam = floor(px + 0.5);
	vec2 d = max(fwidth(px), vec2(1e-5));
	vec2 uv = (seam + clamp((px - seam) / d, -0.5, 0.5)) / size;
	vec4 c = texture(TEXTURE, uv);
	if (enabled) {
		ivec2 p = ivec2(floor(px));
		float b = (BAYER[(p.y % 4) * 4 + (p.x % 4)] + 0.5) / 16.0;
		c.rgb = floor(c.rgb * color_levels + mix(0.5, b, dither_amount)) / color_levels;
	}
	COLOR = vec4(c.rgb, 1.0);
}
