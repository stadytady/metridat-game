// Final pass over the low-res 3D image: 15-bit color with 4x4 ordered dither,
// like the PS1 framebuffer. Applied in low-res pixel space, scaled with nearest.
shader_type canvas_item;

uniform float color_levels = 31.0;
uniform float dither_amount : hint_range(0.0, 1.0) = 0.8;
uniform bool enabled = true;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (enabled) {
		ivec2 p = ivec2(floor(UV * vec2(textureSize(TEXTURE, 0))));
		float b = (BAYER[(p.y % 4) * 4 + (p.x % 4)] + 0.5) / 16.0;
		c.rgb = floor(c.rgb * color_levels + mix(0.5, b, dither_amount)) / color_levels;
	}
	COLOR = vec4(c.rgb, 1.0);
}
