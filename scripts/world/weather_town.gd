class_name WeatherTown
extends District
## The town in the rain, for what has no district of its own to answer it:
## puddles spreading on the paving and drying after, rain drumming on the stoa's
## tiles and the street's roofs, drips off the eaves once it has stopped, the
## market's murmur going quiet, the hearth smoke beaten down; and for the
## places with no clock of their own: the fisherman's net taken in for a storm,
## the flock drawing together on the steppe, the Scythian riders gone off the
## track while it rains. The districts with their own people (TownDay, Life,
## Harbour, GrainQuay, Arrival, Agora) answer the weather themselves.
##
## Everything follows Weather.now() and Weather.wet_now(): the same hour and the
## same walk's seed always give the same town. A change somebody would see happen
## (a net gone, a rider gone) waits until the player is not looking
## (Weather.settle / duty).

## Puddles: Vector3(x, z, radius) on level paving: the agora and the street's foot.
const PUDDLES := [
	Vector3(15.5, 1.5, 0.75), Vector3(19.0, -2.3, 0.55), Vector3(25.5, 4.0, 0.85),
	Vector3(29.8, 1.6, 0.5), Vector3(14.0, 6.0, 0.6), Vector3(24.5, 8.8, 0.55),
	Vector3(6.5, -1.2, 0.5),
]
## Where the rain drums on tiles and drips off them after: under the stoa, and
## by the houses at the foot of the street.
const ROOFS := [Vector3(22.0, 8.6, -7.5), Vector3(-6.0, 0.0, 0.0)]
const MARKET_DB := -22.0
## How much the storm draws the flock together (Sheep.radius times this).
const FLOCK_STORM := 0.35

var _puddles: Array[MeshInstance3D] = []
var _roof: Array[AudioStreamPlayer3D] = []
var _drip: Array[AudioStreamPlayer3D] = []
var _atm: Node
var _market: AudioStreamPlayer3D
var _fishing: Node
var _steppe: Node
var _scythians: Node
var _backdrop: Node


## A puddle's size for this wetness: none on dry stone, spreading as it rains,
## shrinking as it dries.
static func puddle_scale(wet: float) -> float:
	return 0.0 if wet < 0.05 else lerpf(0.35, 1.0, clampf(wet, 0.0, 1.0))


## How loud the rain on the tiles is (0..1): with the rain itself.
static func roof_level(rain: float) -> float:
	return clampf(rain, 0.0, 1.0)


## How loud the drips are (0..1): only once the rain has eased off, while the
## eaves are still wet.
static func drip_level(rain: float, wet: float) -> float:
	return clampf(wet - rain * 1.5, 0.0, 1.0)


## The market's murmur (dB): the sellers and buyers under cover talk low.
static func market_db(rain: float) -> float:
	return MARKET_DB - 12.0 * clampf(rain, 0.0, 1.0)


static func flock_spread(storm: float) -> float:
	return lerpf(1.0, FLOCK_STORM, clampf(storm, 0.0, 1.0))


## Whether the riders are out on the steppe track: not while it rains.
static func riders_out(w: Vector2) -> bool:
	return not Weather.sheltering(w)


## How thick the hearth smoke rises (its particles' amount_ratio): beaten down by rain.
static func smoke_ratio(rain: float) -> float:
	return lerpf(1.0, 0.35, clampf(rain, 0.0, 1.0))


## The level of a puddle's centre: on the paving's own surface.
static func puddle_y(p: Vector3) -> float:
	return Topo.surface(p.x, p.y) + 0.015


func _ready() -> void:
	add_to_group(&"weather_town")
	_atm = get_parent().get_node_or_null("Atmosphere")
	for p: Vector3 in PUDDLES:
		var kit := MeshKit.new()
		kit.max_edge = INF
		# grey: a puddle shows the overcast sky, not a summer sea (alpha is the
		# ambient share, kept at 1: open sky)
		kit.color = Color(0.6, 0.64, 0.7, 1.0)
		var n := 10
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			# a little uneven, so the puddles are not coins
			var r0 := 1.0 + 0.18 * sin(a0 * 3.0 + p.x)
			var r1 := 1.0 + 0.18 * sin(a1 * 3.0 + p.x)
			var e1 := Vector3(cos(a1) * r1, 0, sin(a1) * r1)
			var e0 := Vector3(cos(a0) * r0, 0, sin(a0) * r0)
			kit.tri("trough_water", Vector3.ZERO, e1, e0, Vector2(0.5, 0.5), Vector2(0.5 + e1.x * 0.5, 0.5 + e1.z * 0.5), Vector2(0.5 + e0.x * 0.5, 0.5 + e0.z * 0.5))
		var mi := MeshInstance3D.new()
		mi.name = "Puddle"
		mi.mesh = kit.commit()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(p.x, puddle_y(p), p.y)
		mi.scale = Vector3.ONE * 0.001
		mi.set_meta(&"r", p.z)
		mi.visible = false
		add_child(mi)
		_puddles.append(mi)
	for r: Vector3 in ROOFS:
		var at := r
		if is_zero_approx(r.y):
			# the street's foot: by the houses, on the street's own height
			at = Vector3(r.x, Topo.surface(r.x, Topo.street_z(r.x)) + 3.5, Topo.street_z(r.x) + 3.0)
		for stream: AudioStream in [preload("res://assets/audio/rain_roof.wav"), preload("res://assets/audio/drips.wav")]:
			var s := AudioStreamPlayer3D.new()
			s.stream = stream
			s.position = at
			s.unit_size = 5.0
			s.max_distance = 30.0
			s.volume_db = -80.0
			add_child(s)
			if stream.resource_path.ends_with("rain_roof.wav"):
				_roof.append(s)
			else:
				_drip.append(s)
	var parent := get_parent()
	_fishing = parent.get_node_or_null("FishingCamp")
	_steppe = parent.get_node_or_null("Steppe")
	_scythians = parent.get_node_or_null("Scythians")
	_backdrop = parent.get_node_or_null("Backdrop")


func _hour() -> float:
	return float(_atm.t) if _atm != null else Game.time_target()


func _process(_delta: float) -> void:
	var hour := _hour()
	var w := Weather.now(hour)
	var wet := Weather.wet_now(hour)
	step(w, wet)


## The town for this weather and wetness (the scenarios and tests call it too).
func step(w: Vector2, wet: float) -> void:
	var k := puddle_scale(wet)
	for p: MeshInstance3D in _puddles:
		p.visible = k > 0.0
		if p.visible:
			var r := float(p.get_meta(&"r")) * k
			p.scale = Vector3(r, 1.0, r)
	_level(_roof, roof_level(w.x), "")
	_level(_drip, drip_level(w.x, wet), "CAP_DRIP")
	if _market == null:
		# the ambience is built after this node: look it up once it exists
		var amb := get_parent().get_node_or_null("Ambience")
		if amb != null:
			_market = amb.get_node_or_null("Market") as AudioStreamPlayer3D
	if _market != null:
		_market.volume_db = market_db(w.x)
	if _fishing != null and _fishing.has_method("net") and _fishing.net() != null:
		Weather.settle(_fishing.net(), not Weather.storm_on(w))
	if _steppe != null:
		var spread := flock_spread(w.y)
		for s in _steppe.get_children():
			if s is Sheep:
				if not s.has_meta(&"roam"):
					s.set_meta(&"roam", s.radius)
				s.radius = float(s.get_meta(&"roam")) * spread
	if _scythians != null:
		for r in _scythians.get_children():
			if r is Rider:
				Weather.duty(r, true, not riders_out(w), 60.0)
	if _backdrop != null and _backdrop.has_method("smokes"):
		for sm: GPUParticles3D in _backdrop.smokes():
			sm.amount_ratio = smoke_ratio(w.x)


## A bed of sound at level v (0..1): silent and stopped at 0.
func _level(players: Array[AudioStreamPlayer3D], v: float, caption: String) -> void:
	for s in players:
		if v <= 0.01:
			if s.playing:
				s.stop()
			continue
		s.volume_db = linear_to_db(v) - 8.0
		if not s.playing and s.is_inside_tree():
			s.play()
			if caption != "":
				Game.caption(caption, s.global_position, 15.0)


func puddles() -> Array[MeshInstance3D]:
	return _puddles


func roof_players() -> Array[AudioStreamPlayer3D]:
	return _roof


func drip_players() -> Array[AudioStreamPlayer3D]:
	return _drip
