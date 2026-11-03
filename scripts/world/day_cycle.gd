class_name DayCycle
extends RefCounted
## The hour as one number: 0 = late afternoon (where the game starts),
## ~0.5 sunset, 1 = night. Pure keyframe interpolation, so the look of any
## moment is testable without a renderer.

## t, sun elevation (deg), sun colour, sun energy, ambient colour, ambient
## energy, fog colour, sky weights (day, dusk, night), light tint for unlit
## surfaces (sea, far shore), moon energy.
const KEYS := [
	[0.00, 20.0, Color("#ffbd7a"), 1.9, Color("#8d8078"), 0.70, Color("#d9a774"), Vector3(1, 0, 0), Color(1, 1, 1), 0.0],
	[0.45, 8.0, Color("#ff9a5a"), 1.5, Color("#7a6268"), 0.62, Color("#c98a62"), Vector3(0.3, 0.7, 0), Color(0.9, 0.8, 0.75), 0.0],
	[0.70, 0.5, Color("#ff6a3a"), 0.6, Color("#4e4a62"), 0.52, Color("#7a5a5e"), Vector3(0, 0.75, 0.25), Color(0.6, 0.55, 0.6), 0.1],
	[0.85, -6.0, Color("#000000"), 0.0, Color("#2c3450"), 0.45, Color("#2c3348"), Vector3(0, 0.2, 0.8), Color(0.35, 0.38, 0.5), 0.25],
	[1.00, -12.0, Color("#000000"), 0.0, Color("#1f2740"), 0.42, Color("#1c2336"), Vector3(0, 0, 1), Color(0.28, 0.32, 0.45), 0.35],
]


static func sample(t: float) -> Dictionary:
	t = clampf(t, 0.0, 1.0)
	var i := 0
	while i < KEYS.size() - 2 and t > KEYS[i + 1][0]:
		i += 1
	var a: Array = KEYS[i]
	var b: Array = KEYS[i + 1]
	var k := smoothstep(0.0, 1.0, (t - a[0]) / (b[0] - a[0]))
	return {
		"sun_elevation": lerpf(a[1], b[1], k),
		"sun_color": (a[2] as Color).lerp(b[2], k),
		"sun_energy": lerpf(a[3], b[3], k),
		"ambient_color": (a[4] as Color).lerp(b[4], k),
		"ambient_energy": lerpf(a[5], b[5], k),
		"fog_color": (a[6] as Color).lerp(b[6], k),
		"sky_weights": (a[7] as Vector3).lerp(b[7], k),
		"light_tint": (a[8] as Color).lerp(b[8], k),
		"moon_energy": lerpf(a[9], b[9], k),
	}


## Evening follows the player: each find moves the sun lower, the last one
## brings the night.
static func target_for(found: int, total: int) -> float:
	if total <= 0:
		return 0.0
	return clampf(float(found) / float(total), 0.0, 1.0)
