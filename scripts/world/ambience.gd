extends Node3D
## Wind everywhere, surf along the shore, gulls now and then over the water, the
## market at the square, and the cicadas in the dry grass of the hill — they sing
## while the afternoon is hot and go quiet as the lamps come on.
## All sounds are synthesized by tools/gen_assets.py; loops are set on import.

const GULLS := [preload("res://assets/audio/gull_0.wav"), preload("res://assets/audio/gull_1.wav"), preload("res://assets/audio/gull_2.wav")]
const CICADA := preload("res://assets/audio/cicada.wav")

## Where the cicadas sit: on the hill and along the dry slope below it, so the
## bed belongs to the hill and thins out by the time you are down in the street.
const CICADA_AT: Array[Vector2] = [
	Vector2(-92.0, 7.0), Vector2(-99.0, -8.0), Vector2(-104.0, 16.0),
]
## Their level in the mix, and the hours between which they thin out (DayCycle:
## 0 is late afternoon, 0.78 dusk with the lamps, 1 night).
const CICADA_DB := -18.0
const CICADA_FROM := 0.42
const CICADA_TO := 0.80

var gulls_played := 0
## How loud the cicadas are right now, 1 = the heat of the afternoon, 0 = silent.
var heat := 1.0
var _gull: AudioStreamPlayer3D
var _cicadas: Array[AudioStreamPlayer3D] = []
var _atm: Node
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 8
	var wind := AudioStreamPlayer.new()
	wind.name = "Wind"
	wind.stream = preload("res://assets/audio/wind.wav")
	wind.volume_db = -14.0
	wind.autoplay = true
	add_child(wind)
	for z: float in [-60.0, -20.0, 20.0, 60.0]:
		var surf := AudioStreamPlayer3D.new()
		surf.name = "Surf"
		surf.stream = preload("res://assets/audio/waves.wav")
		surf.position = Vector3(64.0 + Topo.coast_shift(z), 0.5, z)
		surf.unit_size = 22.0
		surf.max_distance = 220.0
		surf.volume_db = -4.0
		surf.autoplay = true
		add_child(surf)
		surf.play(_rng.randf_range(0.0, 10.0))
	_gull = AudioStreamPlayer3D.new()
	_gull.name = "Gull"
	_gull.unit_size = 30.0
	_gull.max_distance = 300.0
	_gull.volume_db = -8.0
	add_child(_gull)
	var timer := Timer.new()
	timer.wait_time = 7.0
	timer.autostart = true
	timer.timeout.connect(func() -> void:
		timer.wait_time = _rng.randf_range(6.0, 16.0)
		_gull.position = Vector3(_rng.randf_range(30, 90), _rng.randf_range(12, 25), _rng.randf_range(-50, 50))
		_gull.stream = GULLS[_rng.randi() % GULLS.size()]
		_gull.pitch_scale = _rng.randf_range(0.92, 1.08)
		_gull.play()
		gulls_played += 1)
	add_child(timer)
	# The market's murmur lives at the square and falls off with the distance.
	var market := AudioStreamPlayer3D.new()
	market.name = "Market"
	market.stream = preload("res://assets/audio/market.wav")
	market.position = Vector3(Topo.AGORA_CENTER.x, Topo.AGORA_H + 1.6, Topo.AGORA_CENTER.y)
	market.volume_db = -22.0
	market.unit_size = 9.0
	market.max_distance = 42.0
	market.autoplay = true
	add_child(market)
	# Now and then someone shouts across the square.
	var cry := AudioStreamPlayer3D.new()
	cry.name = "Cry"
	cry.stream = preload("res://assets/audio/market_cry.wav")
	cry.unit_size = 12.0
	cry.max_distance = 60.0
	cry.volume_db = -15.0
	add_child(cry)
	var cry_timer := Timer.new()
	cry_timer.wait_time = 11.0
	cry_timer.autostart = true
	cry_timer.timeout.connect(func() -> void:
		cry_timer.wait_time = _rng.randf_range(9.0, 24.0)
		cry.position = Vector3(Topo.AGORA_CENTER.x + _rng.randf_range(-6, 6), Topo.AGORA_H + 1.6,
				Topo.AGORA_CENTER.y + _rng.randf_range(-5, 5))
		cry.pitch_scale = _rng.randf_range(0.9, 1.12)
		cry.play())
	add_child(cry_timer)
	_cicadas_at()
	# The city's sounds go quiet in the dream (footsteps remain).
	Game.dream_changed.connect(func(on: bool) -> void:
		for p: Node in get_children():
			if p.has_meta(&"cicada"):
				continue  # the cicadas are faded by _process, which also knows the hour
			if p is AudioStreamPlayer or p is AudioStreamPlayer3D:
				var base: float = p.get_meta(&"base_db", p.volume_db)
				p.set_meta(&"base_db", base)
				p.volume_db = base - (40.0 if on else 0.0)
		timer.paused = on
		cry_timer.paused = on)


## Three cicadas in the grass of the hill, each on its own place in the loop so
## they never beat in step. Their beds are short in reach: heard on the hill and
## down the slope, gone once the street's own noise takes over.
func _cicadas_at() -> void:
	_atm = get_parent().get_node_or_null("Atmosphere")
	for i in CICADA_AT.size():
		var at: Vector2 = CICADA_AT[i]
		var c := AudioStreamPlayer3D.new()
		c.name = "Cicadas%d" % i
		c.stream = CICADA
		c.position = Vector3(at.x, Topo.terrain(at.x, at.y) + 1.1, at.y)
		c.unit_size = 14.0
		c.max_distance = 70.0
		c.volume_db = CICADA_DB
		c.set_meta(&"cicada", true)
		add_child(c)
		_cicadas.append(c)
		c.play(_rng.randf_range(0.0, 12.0))


## The hour decides how much of the afternoon is left in the air: the cicadas
## thin out through the evening and are gone by the time the lamps are lit.
func _process(delta: float) -> void:
	var hour: float = _atm.t if _atm != null else 0.0
	var want := 0.0 if Game.dreaming else 1.0 - smoothstep(CICADA_FROM, CICADA_TO, hour)
	heat = move_toward(heat, want, delta * 0.4)
	var db := CICADA_DB + linear_to_db(maxf(heat, 0.001))
	for c: AudioStreamPlayer3D in _cicadas:
		c.volume_db = db
		if heat > 0.001 and not c.playing:
			c.play(_rng.randf_range(0.0, 12.0))
		elif heat <= 0.001 and c.playing:
			c.stop()

