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
	# The city's sounds go quiet in the dream (footsteps remain).
	Game.dream_changed.connect(func(on: bool) -> void:
		for p: Node in get_children():
			if p is AudioStreamPlayer or p is AudioStreamPlayer3D:
				var base: float = p.get_meta(&"base_db", p.volume_db)
				p.set_meta(&"base_db", base)
				p.volume_db = base - (40.0 if on else 0.0)
		timer.paused = on)

