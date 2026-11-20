class_name Weather
extends Node3D
## A shower off the strait. The hour stays one number (DayCycle); the weather is
## one more, the walk's seed (Game.weather_seed, drawn at a new walk and kept in
## the save): from it rain_at() knows whether this afternoon has a shower and
## when it passes. Atmosphere runs DayCycle.sample through apply(), which only
## greys and thickens what the hour already gives - so a rainy afternoon is
## still that hour, under cloud. Seed 0 is a dry walk: automation, screenshots
## and the trailer always see the same town.
## Here: the rain itself around the camera, streaks driven inland by the wind
## off the sea (Sea.ONSHORE) in gusts, and its sound.

const SOUND := preload("res://assets/audio/rain.wav")

## Of every three walks, one stays dry.
const DRY_ONE_IN := 3
## The shower's middle lies somewhere in the afternoon (DayCycle t), and it takes
## this long (in t) from the first drops to its height and away again.
const SHOWER_FROM := 0.18
const SHOWER_TO := 0.4
const SHOWER_HALF := 0.08
## How far the grey goes at the height of the shower.
const SUN_LEFT := 0.3
const FOG_GREY := Color(0.52, 0.55, 0.6)
const FOG_END_RAIN := 150.0
const FOG_BEGIN_RAIN := 10.0
const HAZE_SKY := 0.55
## The rain box around the camera, and how hard it falls.
const BOX := Vector3(34.0, 14.0, 34.0)
const DROPS := 1400
const FALL := 9.0
## Wind: the drops lean inland, more in the gusts.
const LEAN := 1.6
const GUST := 2.2

var _rain: GPUParticles3D
var _pm: ParticleProcessMaterial
var _sound: AudioStreamPlayer
var _t := 0.0


## How hard it rains at this hour (0 dry .. 1 the height of the shower) on the
## walk with this seed.
static func rain_at(hour: float, seed: int) -> float:
	if seed <= 0 or posmod(seed, DRY_ONE_IN) == 0:
		return 0.0
	var mid := lerpf(SHOWER_FROM, SHOWER_TO, float(posmod(seed * 7919, 1000)) / 999.0)
	var d := absf(hour - mid)
	return 1.0 - smoothstep(SHOWER_HALF * 0.35, SHOWER_HALF, d)


## The hour's look under cloud: weaker sun, a grey fog drawn in close that
## swallows some of the sky, a greyer tint on the sea and the far shore.
static func apply(k: Dictionary, rain: float) -> Dictionary:
	if rain <= 0.0:
		return k
	var out := k.duplicate()
	out.sun_energy = float(k.sun_energy) * lerpf(1.0, SUN_LEFT, rain)
	out.fog_color = (k.fog_color as Color).lerp(FOG_GREY * _luma(k.fog_color) / _luma(FOG_GREY), rain * 0.75)
	out.ambient_color = (k.ambient_color as Color).lerp(_grey(k.ambient_color), rain * 0.6)
	out.light_tint = (k.light_tint as Color).lerp(_grey(k.light_tint), rain * 0.6)
	out.fog_begin = lerpf(float(k.fog_begin), FOG_BEGIN_RAIN, rain)
	out.fog_end = lerpf(float(k.fog_end), FOG_END_RAIN, rain)
	out.fog_sky = maxf(float(k.fog_sky), HAZE_SKY * rain)
	return out


static func _luma(c: Color) -> float:
	return maxf(0.001, c.r * 0.3 + c.g * 0.59 + c.b * 0.11)


static func _grey(c: Color) -> Color:
	var l := _luma(c)
	return Color(l, l, l * 1.04)


## Gusts: how hard the wind leans the rain now, from 0 to 1, in slow surges.
static func gust(t: float) -> float:
	return clampf(0.5 + 0.35 * sin(t * 0.7) + 0.25 * sin(t * 1.9 + 1.3), 0.0, 1.0)


## Where the wind drives the drops (a velocity, m/s), inland off the strait.
static func drift(t: float) -> Vector3:
	var w := LEAN + GUST * gust(t)
	return Vector3(Sea.ONSHORE.x, 0.0, Sea.ONSHORE.y) * w


func _ready() -> void:
	_pm = ParticleProcessMaterial.new()
	_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_pm.emission_box_extents = BOX / 2.0
	_pm.direction = Vector3.DOWN
	_pm.spread = 0.0
	_pm.initial_velocity_min = FALL
	_pm.initial_velocity_max = FALL * 1.15
	_pm.gravity = Vector3.ZERO
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.62, 0.66, 0.72)
	# a streak that stays upright as you turn: drops, not confetti
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var quad := QuadMesh.new()
	quad.size = Vector2(0.025, 0.55)
	quad.material = mat
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = DROPS
	_rain.lifetime = BOX.y / FALL
	_rain.preprocess = _rain.lifetime
	_rain.fixed_fps = 15
	_rain.local_coords = false
	_rain.process_material = _pm
	_rain.draw_pass_1 = quad
	_rain.visibility_aabb = AABB(-BOX, BOX * 2.0)
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain.emitting = false
	_rain.visible = false
	add_child(_rain)
	_sound = AudioStreamPlayer.new()
	_sound.stream = SOUND
	_sound.volume_db = -80.0
	add_child(_sound)


func _hour() -> float:
	var atm := get_parent().get_node_or_null("Atmosphere")
	return float(atm.t) if atm != null else Game.time_target()


func _process(delta: float) -> void:
	_t += delta
	var r := 0.0 if Game.dreaming or Game.prologue else rain_at(_hour(), Game.weather_seed)
	step(r)


## Rain at strength r: the box follows the camera, thins and thickens with r,
## leans with the gusts; the sound swells with it.
func step(r: float) -> void:
	var on := r > 0.02
	if on != _rain.emitting:
		_rain.emitting = on
		_rain.visible = on
		if on:
			_sound.play()
		else:
			_sound.stop()
	if not on:
		return
	_rain.amount_ratio = clampf(r, 0.05, 1.0)
	_pm.gravity = drift(_t)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var c := cam.global_position
		_rain.global_position = Vector3(c.x, c.y + BOX.y * 0.35, c.z) - drift(_t) * 0.5
	_sound.volume_db = linear_to_db(maxf(r, 0.001)) - 4.0


## Whether it is raining now (for tests and scenarios).
func raining() -> bool:
	return _rain.emitting
