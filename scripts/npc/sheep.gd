class_name Sheep
extends Node3D
## A sheep on the far steppe: a blocky body, a head that mostly grazes and now and
## then lifts, and a slow wander that never leaves the pasture. Nothing collides
## and nothing is interactable: it is there to be seen from the hill.

const BODY := Vector3(0.58, 0.44, 0.85)
const LEG := Vector3(0.07, 0.3, 0.07)
## Head pitch in degrees: down to graze, up to look around.
const GRAZE := -26.0
const LIFT := 2.0
## One graze-then-lift cycle, seconds.
const CYCLE := 7.0

var home := Vector3.ZERO
var radius := 4.0
var _head: Node3D
var _t := 0.0
var _wait := 0.0
var _target := Vector3.ZERO
var _baa: AudioStreamPlayer3D


## Head pitch at a moment of the cycle: down most of the time, up for a moment.
static func head_angle(t: float) -> float:
	var phase := fposmod(t, CYCLE) / CYCLE
	if phase < 0.78:
		return GRAZE
	# Lift and lower again over the remaining fifth, smoothly.
	var k := (phase - 0.78) / 0.22
	return lerpf(GRAZE, LIFT, sin(k * PI))


## The next spot to amble to: `angle` turns the walk, `radius` keeps it home.
static func next_stop(home: Vector3, radius: float, angle: float) -> Vector3:
	var r := radius * (0.35 + 0.65 * absf(sin(angle * 1.7)))
	return home + Vector3(sin(angle) * r, 0.0, cos(angle) * r)


func _ready() -> void:
	_t = randf() * CYCLE
	var kit := MeshKit.new()
	kit.box("fleece", Vector3(0, 0.5, 0), BODY, ["bottom"], {"top": "fleece"})
	# a woolly back, so the silhouette is not a plain box
	kit.box("fleece", Vector3(0, 0.71, -0.02), BODY * Vector3(0.72, 0.22, 0.78), ["bottom"], {})
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			kit.box("dark", Vector3(sx * 0.17, 0.15, sz * 0.26), LEG, ["top", "bottom"], {})
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 0.56, 0.4)
	add_child(_head)
	var hk := MeshKit.new()
	hk.box("dark", Vector3(0, 0, 0.14), Vector3(0.19, 0.21, 0.28), ["bottom"], {})
	hk.box("skin", Vector3(0, 0.04, 0.31), Vector3(0.12, 0.11, 0.09), ["bottom"], {})
	for sx: float in [-1.0, 1.0]:
		hk.box("dark", Vector3(sx * 0.12, 0.1, 0.08), Vector3(0.04, 0.12, 0.09), ["bottom"], {})
	var mi := MeshInstance3D.new()
	mi.mesh = hk.commit()
	_head.add_child(mi)
	var body := MeshInstance3D.new()
	body.mesh = kit.commit()
	add_child(body)
	_baa = AudioStreamPlayer3D.new()
	_baa.stream = preload("res://assets/audio/sheep.wav")
	_baa.volume_db = -20.0
	_baa.unit_size = 3.0
	_baa.max_distance = 55.0
	add_child(_baa)
	var timer := Timer.new()
	timer.wait_time = randf_range(18.0, 46.0)
	timer.autostart = true
	timer.timeout.connect(func() -> void:
		timer.wait_time = randf_range(22.0, 55.0)
		_baa.pitch_scale = randf_range(0.88, 1.12)
		_baa.play())
	add_child(timer)
	_target = next_stop(home, radius, randf() * TAU)


func _process(delta: float) -> void:
	_t += delta
	_head.rotation.x = deg_to_rad(head_angle(_t))
	if _wait > 0.0:
		_wait = maxf(0.0, _wait - delta)
		return
	var to := _target - global_position
	to.y = 0.0
	if to.length() < 0.25:
		_wait = randf_range(2.0, 7.0)
		_target = next_stop(home, radius, randf() * TAU)
		return
	# Grazing sheep move by fits: slow, and only when the head is up.
	if head_angle(_t) < GRAZE + 12.0:
		return
	var step := minf(0.45 * delta, to.length())
	global_position += to / to.length() * step
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), delta * 2.0)
	global_position.y = Topo.terrain(global_position.x, global_position.z)
