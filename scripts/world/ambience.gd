extends Node3D
## Wind everywhere, surf along the shore, gulls now and then over the water.
## All sounds are synthesized by tools/gen_assets.py; loops are set on import.

const GULLS := [preload("res://assets/audio/gull_0.wav"), preload("res://assets/audio/gull_1.wav"), preload("res://assets/audio/gull_2.wav")]

var gulls_played := 0
var _gull: AudioStreamPlayer3D
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
	# The city's sounds go quiet in the dream (footsteps remain).
	Game.dream_changed.connect(func(on: bool) -> void:
		for p: Node in get_children():
			if p is AudioStreamPlayer or p is AudioStreamPlayer3D:
				var base: float = p.get_meta(&"base_db", p.volume_db)
				p.set_meta(&"base_db", base)
				p.volume_db = base - (40.0 if on else 0.0)
		timer.paused = on
		cry_timer.paused = on)

