class_name Chicken
extends Node3D
## A hen or a rooster, built like Figure from rigid parts and animated at a
## stepped 15 fps. Wanders and pecks around its home, scatters from the player
## with a squawk and a flap, roosts at night. No collider: it must never block
## the route (AGENTS.md, invariant 4). Faces -Z.

enum State { IDLE, WALK, PECK, FLEE, ROOST }

const FLEE_DIST := 2.5
const CALM_DIST := 4.0
const WALK_SPEED := 0.45
const FLEE_SPEED := 2.4
const CLUCKS := [preload("res://assets/audio/cluck_0.wav"), preload("res://assets/audio/cluck_1.wav"),
	preload("res://assets/audio/cluck_2.wav")]
const SQUAWK := preload("res://assets/audio/squawk.wav")

var home := Vector3.ZERO
var radius := 1.5
var rooster := false
var feathers := "hen"
var state := State.IDLE
## How many times it has scattered: the walkthrough checks it.
var fled := 0

var _target := Vector3.ZERO
var _timer := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _parts := {}
var _voice: AudioStreamPlayer3D
var _cluck_in := 0.0


func _ready() -> void:
	add_to_group(&"chicken")
	_rng.seed = hash(name) ^ int(home.x * 100.0) ^ int(home.z * 100.0)
	_build()
	scale = Vector3.ONE * (1.2 if rooster else 1.0)
	position = home + Vector3(_rng.randf_range(-0.5, 0.5), 0, _rng.randf_range(-0.5, 0.5)) * radius
	rotation.y = _rng.randf_range(0, TAU)
	_t = _rng.randf() * 10.0
	_timer = _rng.randf_range(0.5, 2.0)
	_cluck_in = _rng.randf_range(3.0, 12.0)
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 3.0
	_voice.max_distance = 25.0
	_voice.volume_db = -6.0
	add_child(_voice)


func _part(name: String, parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	parent.add_child(n)
	_parts[name] = n
	return n


func _mesh(parent: Node3D, kit: MeshKit) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	parent.add_child(mi)


func _build() -> void:
	var tail_mat := "rooster_tail" if rooster else feathers
	var body := _part("body", self, Vector3(0, 0.2, 0))
	var k := MeshKit.new()
	k.box(feathers, Vector3(0, 0.02, 0), Vector3(0.18, 0.17, 0.27), [])
	k.box(feathers, Vector3(0, -0.07, -0.03), Vector3(0.14, 0.06, 0.18), [])  # breast
	if rooster:  # tall, arched sickle feathers
		k.box(tail_mat, Vector3(0, 0.16, 0.16), Vector3(0.05, 0.26, 0.1), [])
		k.box(tail_mat, Vector3(0, 0.22, 0.24), Vector3(0.04, 0.12, 0.1), [])
	else:
		k.box(tail_mat, Vector3(0, 0.1, 0.15), Vector3(0.1, 0.13, 0.07), [])
	_mesh(body, k)
	for s: float in [1.0, -1.0]:
		var wing := _part("wing_l" if s < 0 else "wing_r", body, Vector3(0.095 * s, 0.07, 0))
		var wk := MeshKit.new()
		wk.box(feathers, Vector3(0.012 * s, -0.04, 0.02), Vector3(0.025, 0.11, 0.2), [])
		_mesh(wing, wk)
		var leg := _part("leg_l" if s < 0 else "leg_r", self, Vector3(0.045 * s, 0.14, 0.01))
		var lk := MeshKit.new()
		lk.box("beak", Vector3(0, -0.07, 0), Vector3(0.022, 0.14, 0.022), [])
		lk.box("beak", Vector3(0, -0.135, -0.03), Vector3(0.05, 0.012, 0.07), [])
		_mesh(leg, lk)
	var neck := _part("neck", body, Vector3(0, 0.08, -0.11))
	var nk := MeshKit.new()
	nk.box(feathers, Vector3(0, 0.06, -0.01), Vector3(0.08, 0.13, 0.08), [])
	nk.box(feathers, Vector3(0, 0.14, -0.03), Vector3(0.075, 0.07, 0.09), [])  # head
	nk.box("beak", Vector3(0, 0.135, -0.09), Vector3(0.025, 0.02, 0.04), [])
	var comb_h := 0.06 if rooster else 0.03
	nk.box("comb", Vector3(0, 0.175 + comb_h / 2.0, -0.03), Vector3(0.015, comb_h, 0.07), [])
	nk.box("comb", Vector3(0, 0.1, -0.075), Vector3(0.015, 0.035 if rooster else 0.02, 0.02), [])  # wattle
	_mesh(neck, nk)


## Keeps a point inside the home circle (flat: y is the home floor).
static func clamp_home(p: Vector3, home_pos: Vector3, r: float) -> Vector3:
	var d := Vector2(p.x - home_pos.x, p.z - home_pos.z)
	if d.length() > r:
		d = d.normalized() * r
	return Vector3(home_pos.x + d.x, home_pos.y, home_pos.z + d.y)


## Where to run from a threat without leaving home: straight away if there is
## room, else the point on the home circle farthest from the threat.
static func flee_target(p: Vector3, threat: Vector3, home_pos: Vector3, r: float) -> Vector3:
	var away := Vector2(p.x - threat.x, p.z - threat.z)
	if away.length() < 0.01:
		away = Vector2(1, 0)
	var best := clamp_home(p + Vector3(away.x, 0, away.y).normalized() * 1.5, home_pos, r)
	var t2 := Vector2(threat.x, threat.z)
	for i in 12:
		var a := TAU * i / 12.0
		var c := home_pos + Vector3(cos(a), 0, sin(a)) * r * 0.95
		if Vector2(c.x, c.z).distance_to(t2) > Vector2(best.x, best.z).distance_to(t2) + 0.3:
			best = c
	return best


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	var threat := cam.global_position if cam else Vector3(INF, 0, INF)
	var dist := Vector2(global_position.x - threat.x, global_position.z - threat.z).length()
	if dist > 70.0:
		return  # behind the fog: no work
	_think(delta, threat, dist)
	_animate()


func _think(delta: float, threat: Vector3, dist: float) -> void:
	_timer -= delta
	var night := Game.time_target() >= 0.85
	if night and state != State.ROOST and state != State.FLEE:
		state = State.ROOST
	elif not night and state == State.ROOST:
		state = State.IDLE
	if dist < FLEE_DIST and state != State.FLEE and state != State.ROOST:
		state = State.FLEE
		fled += 1
		_target = flee_target(global_position, threat, home, radius)
		_say(SQUAWK)
	match state:
		State.IDLE:
			if _timer <= 0.0:
				if _rng.randf() < 0.45:
					_start_peck()
				else:
					state = State.WALK
					var a := _rng.randf_range(0, TAU)
					_target = clamp_home(home + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(0.2, radius), home, radius)
		State.WALK:
			if _move(delta, WALK_SPEED):
				_start_peck()
		State.PECK:
			if _timer <= 0.0:
				state = State.IDLE
				_timer = _rng.randf_range(0.6, 2.5)
		State.FLEE:
			var arrived := _move(delta, FLEE_SPEED)
			if arrived and dist > FLEE_DIST:
				state = State.IDLE
				_timer = _rng.randf_range(0.3, 1.0)
			elif arrived:
				_target = flee_target(global_position, threat, home, radius)
	if state != State.FLEE and state != State.ROOST:
		_cluck_in -= delta
		if _cluck_in <= 0.0 and dist < CALM_DIST * 4.0:
			_say(CLUCKS[_rng.randi() % CLUCKS.size()])
			_cluck_in = _rng.randf_range(6.0, 16.0)


func _start_peck() -> void:
	state = State.PECK
	_timer = _rng.randf_range(1.2, 3.5)


## Steps towards _target, turning to face it; true on arrival.
func _move(delta: float, speed: float) -> bool:
	var d := Vector3(_target.x - position.x, 0, _target.z - position.z)
	if d.length() < 0.05:
		return true
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), minf(1.0, delta * 12.0))
	position += d.normalized() * minf(d.length(), speed * delta)
	position.y = home.y
	return false


func _say(stream: AudioStream) -> void:
	if _voice and is_inside_tree():
		_voice.stream = stream
		_voice.pitch_scale = (0.85 if rooster else 1.0) * _rng.randf_range(0.92, 1.08)
		_voice.play()


func _animate() -> void:
	var q := floorf(_t * 15.0) / 15.0  # PS1-era stepped animation
	var body: Node3D = _parts.body
	var neck: Node3D = _parts.neck
	var legs := [_parts.leg_l, _parts.leg_r]
	var wings := [_parts.wing_l, _parts.wing_r]
	var leg_x := 0.0
	var neck_x := 0.0
	var wing_z := 0.0
	var body_y := 0.2
	var body_x := 0.0
	match state:
		State.WALK:
			leg_x = sin(q * 14.0) * 30.0
			neck_x = sin(q * 14.0) * 10.0  # the head bob
		State.PECK:
			var k := fposmod(q * 2.2, 1.0)
			neck_x = -75.0 if k < 0.3 else 0.0
			body_x = -18.0 if k < 0.3 else 0.0
		State.FLEE:
			leg_x = sin(q * 30.0) * 45.0
			wing_z = 40.0 + sin(q * 40.0) * 35.0
			body_x = -10.0
		State.ROOST:
			body_y = 0.11  # settled down over its feet
			neck_x = 20.0
		_:
			neck_x = sin(q * 1.3) * 6.0
	body.position.y = body_y
	body.rotation_degrees.x = body_x
	neck.rotation_degrees.x = neck_x
	for i in 2:
		(legs[i] as Node3D).rotation_degrees.x = leg_x * (1.0 if i == 0 else -1.0)
		(legs[i] as Node3D).visible = state != State.ROOST
		(wings[i] as Node3D).rotation_degrees.z = wing_z * (-1.0 if i == 0 else 1.0)
