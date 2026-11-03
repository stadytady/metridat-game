// Painted panorama sky that blends day, dusk and night (weights from DayCycle).
// Nearest sampling keeps the hand-painted bands hard, as on the PS1.
shader_type sky;

uniform sampler2D day_tex : source_color, filter_nearest;
uniform sampler2D dusk_tex : source_color, filter_nearest;
uniform sampler2D night_tex : source_color, filter_nearest;
uniform vec3 weights = vec3(1.0, 0.0, 0.0);

void sky() {
	vec2 uv = SKY_COORDS;
	vec3 c = texture(day_tex, uv).rgb * weights.x
			+ texture(dusk_tex, uv).rgb * weights.y
			+ texture(night_tex, uv).rgb * weights.z;
	COLOR = c / max(weights.x + weights.y + weights.z, 0.001);
}
