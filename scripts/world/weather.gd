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
## Some wet walks get a storm instead of a shower (kind()): longer and darker,
## harder wind, a heavier swell on the strait (Sea.swell), lightning that
## Atmosphere turns into a flash of light (flash()) and thunder after it
## (thunders()). Both are clocks, not state: the same Weather.clock gives the
## same bolts to the light and to the sound.
## The developer menu can force the weather (Game.weather_override); now()
## is the one place that knows about it, everything else asks now().

const SOUND := preload("res://assets/audio/rain.wav")
const THUNDER := preload("res://assets/audio/thunder.wav")
const WIND := preload("res://assets/audio/gale.wav")

## What a walk's afternoon brings.
enum { DRY, SHOWER, STORM }
## Of the walks that rain, one in this many gets a storm.
const STORM_ONE_IN := 4
## A storm lasts longer (in t) than a shower, still gone well before dusk.
const STORM_HALF := 0.12
## At the height of a storm, on top of the shower's grey: the sun nearly out,
## the haze darker and closer, the swell this much higher.
const STORM_SUN := 0.35
const STORM_DARK := 0.62
const STORM_FOG_END := 95.0
const STORM_AMBIENT := 0.7
const STORM_SWELL := 1.5
## How much of the painted sky the storm's cloud covers.
const STORM_SKY := 0.9
## The wind in a storm drives the rain this much harder.
const STORM_WIND := 1.3
## Lightning: the sky is cut into windows of BOLT_EVERY seconds; in a window a
## bolt falls with BOLT_CHANCE, at a moment drawn from the window's number. Its
## light lasts BOLT_LIGHT s (two pulses), its thunder comes 1..THUNDER_LAG s
## later, as from a few kilometres off.
const BOLT_EVERY := 6.0
const BOLT_CHANCE := 0.65
const BOLT_LIGHT := 0.35
const THUNDER_LAG := 4.0
## Below this storm strength there is no lightning: only the heart of the storm.
const BOLT_FROM := 0.5

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
const DROPS := 2400
## A shower at its height fills this share of DROPS; a storm all of them.
const SHOWER_DROPS := 0.58
const FALL := 9.0
## Wind: the drops lean inland, more in the gusts.
const LEAN := 1.6
const GUST := 2.2

var _rain: GPUParticles3D
var _pm: ParticleProcessMaterial
var _sound: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _thunder: AudioStreamPlayer
var _t := 0.0
## Seconds on the weather's clock: the bolts' light (Atmosphere) and their
## thunder (here) read the same one.
static var clock := 0.0


## What this walk's afternoon brings.
static func kind(seed: int) -> int:
	if seed <= 0 or posmod(seed, DRY_ONE_IN) == 0:
		return DRY
	return STORM if posmod((seed * 2246822519) >> 13, STORM_ONE_IN) == 0 else SHOWER


## How hard it rains at this hour (0 dry .. 1 the height of the shower) on the
## walk with this seed.
static func rain_at(hour: float, seed: int) -> float:
	var k := kind(seed)
	if k == DRY:
		return 0.0
	var half := STORM_HALF if k == STORM else SHOWER_HALF
	var mid := lerpf(SHOWER_FROM, SHOWER_TO, float(posmod(seed * 7919, 1000)) / 999.0)
	var d := absf(hour - mid)
	return 1.0 - smoothstep(half * 0.35, half, d)


## How much of that rain is storm (0 .. 1): all of it on a storm walk.
static func storm_at(hour: float, seed: int) -> float:
	return rain_at(hour, seed) if kind(seed) == STORM else 0.0


## The weather now: Vector2(rain, storm). None in the dream or the prologue; the
## developer menu's choice (Game.weather_override) over the walk's own.
static func now(hour: float) -> Vector2:
	if Game.dreaming or Game.prologue:
		return Vector2.ZERO
	match Game.weather_override:
		DRY:
			return Vector2.ZERO
		SHOWER:
			return Vector2(1.0, 0.0)
		STORM:
			return Vector2(1.0, 1.0)
	return Vector2(rain_at(hour, Game.weather_seed), storm_at(hour, Game.weather_seed))


## How wet the town is: the rain itself while it falls, then lingering and
## drying for DRY_AFTER of the hour once it has stopped (puddles, drips). Pure:
## sampled back along the hour, no memory.
const DRY_AFTER := 0.06
## People take cover from this much rain, and the harbour and the steppe give
## way to the storm from this much of it.
const SHELTER_AT := 0.35
const STORM_ON := 0.5


static func wet_at(hour: float, seed: int) -> float:
	var w := 0.0
	for i in 9:
		var back := DRY_AFTER * i / 8.0
		w = maxf(w, rain_at(hour - back, seed) * (1.0 - float(i) / 8.0))
	return w


## The wetness now: the menu's shower or storm soaks at once, its dry dries at once.
static func wet_now(hour: float) -> float:
	if Game.dreaming or Game.prologue:
		return 0.0
	match Game.weather_override:
		DRY:
			return 0.0
		SHOWER, STORM:
			return 1.0
	return wet_at(hour, Game.weather_seed)


## Whether people go under cover in this weather (Vector2(rain, storm) from now()).
static func sheltering(w: Vector2) -> bool:
	return w.x >= SHELTER_AT


## Whether the storm has the harbour and the steppe: work there stops.
static func storm_on(w: Vector2) -> bool:
	return w.y >= STORM_ON


## Whether a person or a thing can change state (go under cover, come back, be
## carried in) without the player seeing it pop: far off, or out of view. The
## town then catches up with the weather wherever the player is not looking.
static func unseen(n: Node3D, far := 28.0) -> bool:
	if not n.is_inside_tree():
		return true
	var cam := n.get_viewport().get_camera_3d()
	if cam == null:
		return true
	# a MeshKit-built node sits at the origin with its mesh in world space: it
	# names where it really is in its "focus" meta
	var p: Vector3 = n.get_meta(&"focus", n.global_position) + Vector3(0, 1.0, 0)
	return cam.global_position.distance_to(p) > far or not cam.is_position_in_frustum(p)


## Shows or hides `n` for the weather, but only once the player cannot see it
## happen (unseen()); a hidden Npc stops walking too. Returns whether it is now
## as wanted.
static func settle(n: Node3D, want: bool, far := 28.0) -> bool:
	if n.visible == want:
		return true
	if not unseen(n, far):
		return false
	n.visible = want
	if n is Npc:
		_wake(n as Npc, want)
	return true


## Someone whose day (on_duty: at work by the hour) and the weather (take_cover)
## decide where they are. The hour acts at once, as it always has; going under
## cover and coming back out wait until the player is not looking (unseen()),
## so nobody vanishes in front of them. Returns whether they are under cover.
static func duty(n: Node3D, on_duty: bool, take_cover: bool, far := 28.0) -> bool:
	var covered := bool(n.get_meta(&"cover", false))
	if not on_duty:
		covered = false
	elif take_cover != covered and unseen(n, far):
		covered = take_cover
	n.set_meta(&"cover", covered)
	var want := on_duty and not covered
	if n.visible != want:
		n.visible = want
		if n is Npc:
			_wake(n as Npc, want)
	return covered


## A person put away is gone altogether: not walking, and no body left behind
## to bump into.
static func _wake(n: Npc, on: bool) -> void:
	n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	n.collision_layer = (3 if n.solid else (2 if n.talkable else 0)) if on else 0


## A number in 0..1 drawn from a bolt window's index: the same window always
## draws the same, so light and thunder agree without being told.
static func _draw(n: int, salt: int) -> float:
	return float(posmod((n * 73856093) ^ (salt * 19349663), 10007)) / 10006.0


## When the bolt of window n falls (s on the clock), or -1 if that window has none.
static func bolt_time(n: int) -> float:
	if _draw(n, 1) > BOLT_CHANCE:
		return -1.0
	return (n + 0.1 + 0.6 * _draw(n, 2)) * BOLT_EVERY


## How bright the lightning is at clock time t (0..1) in a storm this strong:
## two hard pulses, stepped at 15 frames a second like every other light here.
static func flash(t: float, storm: float) -> float:
	if storm < BOLT_FROM:
		return 0.0
	var q := floorf(t * 15.0) / 15.0
	var b := bolt_time(floori(q / BOLT_EVERY))
	if b < 0.0 or q < b or q > b + BOLT_LIGHT:
		return 0.0
	var u := (q - b) / BOLT_LIGHT
	var pulse := 1.0 if u < 0.25 else (0.25 if u < 0.5 else 0.8 * (1.0 - u))
	return pulse * smoothstep(BOLT_FROM, 1.0, storm)


## The bolts whose thunder arrives in (t0, t1]: their windows' numbers.
static func thunders(t0: float, t1: float) -> Array[int]:
	var out: Array[int] = []
	if t1 <= t0:
		return out
	for n in range(floori((t0 - THUNDER_LAG - BOLT_EVERY) / BOLT_EVERY), floori(t1 / BOLT_EVERY) + 1):
		var b := bolt_time(n)
		if b < 0.0:
			continue
		var heard := b + thunder_lag(n)
		if heard > t0 and heard <= t1:
			out.append(n)
	return out


## How long after its light a bolt is heard.
static func thunder_lag(n: int) -> float:
	return lerpf(1.0, THUNDER_LAG, _draw(n, 3))


## The hour's look under cloud: weaker sun, a grey fog drawn in close that
## swallows some of the sky, a greyer tint on the sea and the far shore.
static func apply(k: Dictionary, rain: float, storm := 0.0) -> Dictionary:
	if rain <= 0.0:
		return k
	var out := k.duplicate()
	out.sun_energy = float(k.sun_energy) * lerpf(1.0, SUN_LEFT, rain) * lerpf(1.0, STORM_SUN, storm)
	var fog := (k.fog_color as Color).lerp(FOG_GREY * _luma(k.fog_color) / _luma(FOG_GREY), rain * 0.75)
	# a storm's cloud is slate, not the hour's warm haze: cooler and darker, kept
	# relative to the hour's brightness so a storm at night stays night
	var slate := Color(0.86, 0.95, 1.1) * _luma(fog) * STORM_DARK
	out.fog_color = fog.lerp(Color(slate.r, slate.g, slate.b), storm)
	out.ambient_color = (k.ambient_color as Color).lerp(_grey(k.ambient_color), rain * 0.6)
	out.ambient_energy = float(k.ambient_energy) * lerpf(1.0, STORM_AMBIENT, storm)
	out.light_tint = (k.light_tint as Color).lerp(_grey(k.light_tint), rain * 0.6)
	out.fog_begin = lerpf(float(k.fog_begin), FOG_BEGIN_RAIN, rain)
	out.fog_end = lerpf(lerpf(float(k.fog_end), FOG_END_RAIN, rain), STORM_FOG_END, storm)
	out.fog_sky = maxf(float(k.fog_sky), HAZE_SKY * rain + (STORM_SKY - HAZE_SKY) * storm)
	return out


## A bolt's light over the hour's look: ambient and haze go pale for an instant
## (flat, the whole town at once, as a flash reads at this resolution).
static func lit_by_bolt(k: Dictionary, f: float) -> Dictionary:
	if f <= 0.0:
		return k
	var out := k.duplicate()
	out.ambient_color = (k.ambient_color as Color).lerp(BOLT_COLOR, f * 0.8)
	out.ambient_energy = float(k.ambient_energy) + BOLT_AMBIENT * f
	out.fog_color = (k.fog_color as Color).lerp(BOLT_COLOR, f * 0.6)
	out.light_tint = (k.light_tint as Color).lerp(Color.WHITE, f * 0.5)
	return out


const BOLT_COLOR := Color(0.78, 0.82, 0.95)
const BOLT_AMBIENT := 1.6


static func _luma(c: Color) -> float:
	return maxf(0.001, c.r * 0.3 + c.g * 0.59 + c.b * 0.11)


static func _grey(c: Color) -> Color:
	var l := _luma(c)
	return Color(l, l, l * 1.04)


## Gusts: how hard the wind leans the rain now, from 0 to 1, in slow surges.
static func gust(t: float) -> float:
	return clampf(0.5 + 0.35 * sin(t * 0.7) + 0.25 * sin(t * 1.9 + 1.3), 0.0, 1.0)


## Where the wind drives the drops (a velocity, m/s), inland off the strait;
## harder in a storm.
static func drift(t: float, storm := 0.0) -> Vector3:
	var w := (LEAN + GUST * gust(t)) * (1.0 + STORM_WIND * storm)
	return Vector3(Sea.ONSHORE.x, 0.0, Sea.ONSHORE.y) * w


## How a drop flies (m/s): falling at FALL and carried inland by the wind. The
## streak is drawn along this, so the harder the wind the more the rain slants.
static func fall_velocity(t: float, storm := 0.0) -> Vector3:
	return Vector3.DOWN * FALL + drift(t, storm)


## How far from the vertical the rain slants (deg) at this velocity.
static func slant_deg(v: Vector3) -> float:
	return rad_to_deg(atan2(Vector2(v.x, v.z).length(), -v.y))


## A streak as two crossed thin quads along y: aligned to its flight (not
## billboarded, which would stand it upright), it still shows from any side.
static func streak_mesh(mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := 0.0125
	var hh := 0.275
	for side: Vector3 in [Vector3(hw, 0, 0), Vector3(0, 0, hw)]:
		var up := Vector3(0, hh, 0)
		var a := -side - up
		var b := side - up
		var c := side + up
		var d := -side + up
		for v: Vector3 in [a, b, c, a, c, d]:
			st.add_vertex(v)
	st.set_material(mat)
	return st.commit()


func _ready() -> void:
	_pm = ParticleProcessMaterial.new()
	_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_pm.emission_box_extents = BOX / 2.0
	_pm.direction = Vector3.DOWN
	_pm.spread = 0.0
	_pm.initial_velocity_min = FALL
	_pm.initial_velocity_max = FALL * 1.15
	_pm.gravity = Vector3.ZERO
	# the streak lies along its flight: slanted by the wind, not standing upright
	_pm.particle_flag_align_y = true
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.62, 0.66, 0.72)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# a drop a hand's breadth from the eye is a white bar across the screen:
	# dither it out up close (a screen-door, no blending)
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	mat.distance_fade_min_distance = 0.8
	mat.distance_fade_max_distance = 2.5
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = DROPS
	_rain.lifetime = BOX.y / FALL
	_rain.preprocess = _rain.lifetime
	_rain.fixed_fps = 15
	_rain.local_coords = false
	_rain.process_material = _pm
	_rain.draw_pass_1 = streak_mesh(mat)
	_rain.visibility_aabb = AABB(-BOX, BOX * 2.0)
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain.emitting = false
	_rain.visible = false
	add_child(_rain)
	_sound = AudioStreamPlayer.new()
	_sound.stream = SOUND
	_sound.volume_db = -80.0
	add_child(_sound)
	_wind = AudioStreamPlayer.new()
	_wind.stream = WIND
	_wind.volume_db = -80.0
	add_child(_wind)
	_thunder = AudioStreamPlayer.new()
	_thunder.stream = THUNDER
	add_child(_thunder)


func _hour() -> float:
	var atm := get_parent().get_node_or_null("Atmosphere")
	return float(atm.t) if atm != null else Game.time_target()


func _process(delta: float) -> void:
	_t += delta
	var t0 := clock
	clock = fmod(clock + delta, 3600.0)
	var w := now(_hour())
	step(w.x, w.y)
	# the swell builds and lays over minutes, not at once (the menu snaps the sky)
	Sea.swell = move_toward(Sea.swell, lerpf(1.0, STORM_SWELL, w.y), delta * 0.05)
	if w.y >= BOLT_FROM and clock > t0:
		for n in thunders(t0, clock):
			_thunder.pitch_scale = lerpf(0.8, 1.1, _draw(n, 4))
			# the near ones loud, the far ones a rumble
			_thunder.volume_db = lerpf(0.0, -12.0, (thunder_lag(n) - 1.0) / (THUNDER_LAG - 1.0))
			_thunder.play()
			Game.caption("CAP_THUNDER", _rain.global_position, INF)


## Rain at strength r (storm the share of it that is storm): the box follows the
## camera, thins and thickens with r, leans with the gusts; the sound swells with it.
func step(r: float, storm := 0.0) -> void:
	var on := r > 0.02
	if on != _rain.emitting:
		_rain.emitting = on
		_rain.visible = on
		if on:
			_sound.play()
			_wind.play()
		else:
			_sound.stop()
			_wind.stop()
	if not on:
		return
	_rain.amount_ratio = clampf(r * lerpf(SHOWER_DROPS, 1.0, storm), 0.05, 1.0)
	# rain is everywhere: its caption once at the start and now and then after
	if r > 0.3:
		Game.caption("CAP_STORM" if storm > 0.5 else "CAP_RAIN", _rain.global_position, INF, 30000)
	# the wind goes into each new drop's speed, so it flies (and is drawn)
	# slanted; drops already falling keep the gust they left with
	var v := fall_velocity(_t, storm)
	_pm.direction = v.normalized()
	_pm.initial_velocity_min = v.length()
	_pm.initial_velocity_max = v.length() * 1.15
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var c := cam.global_position
		# born upwind, so that where they land is round the camera
		var d := drift(_t, storm)
		_rain.global_position = Vector3(c.x, c.y + BOX.y * 0.35, c.z) - d * _rain.lifetime * 0.5
	_sound.volume_db = linear_to_db(maxf(r, 0.001)) - 4.0 + 4.0 * storm
	# the wind is only heard in a storm, and it surges with the gusts
	_wind.volume_db = linear_to_db(maxf(storm * lerpf(0.55, 1.0, gust(_t)), 0.001)) - 2.0


## Whether it is raining now (for tests and scenarios).
func raining() -> bool:
	return _rain.emitting


## How far the new drops slant from the vertical now (deg), for scenarios.
func slant() -> float:
	return slant_deg(_pm.direction)
