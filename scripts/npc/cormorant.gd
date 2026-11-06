class_name Cormorant
extends Node3D
## A cormorant on the beach: black, upright, a long neck and a hooked bill.
## It stands, waddles about its patch of sand, preens, and above all stands with
## its wings held out to the sides to dry them, as cormorants do after fishing,
## now and then giving them a shake. Built from rigid parts like Chicken and
## stepped at 15 fps. No collider: never in anyone's way. Faces -Z.

enum State { STAND, WALK, DRY, PREEN }

const WALK_SPEED := 0.3
## How far the wings open when it dries them, degrees about its own vertical.
const DRY_SPREAD := 82.0
## A bird that keeps away from people: it waddles off when they come closer.
const SHY_DIST := 3.0

var home := Vector3.ZERO
var radius := 2.0
## On a rock it stays put; on the sand it walks, on the sand's own height.
var on_rock := false
var state := State.STAND
## What it has done: the test reads these.
var dried := 0.0
var walked := 0.0

var _target := Vector3.ZERO
var _timer := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _parts := {}


func _ready() -> void:
	add_to_group(&"cormorant")
	_rng.seed = hash(name) ^ int(home.x * 100.0) ^ int(home.z * 100.0)
	_build()
	position = home
	if not on_rock:
		position += Vector3(_rng.randf_range(-0.5, 0.5), 0, _rng.randf_range(-0.5, 0.5)) * radius
		position.y = ground(position)
	rotation.y = _rng.randf_range(0, TAU)
	_t = _rng.randf() * 10.0
	_choose()


## The sand under a point; a rock-sitter keeps the height it was put at.
func ground(p: Vector3) -> float:
	return home.y if on_rock else Topo.terrain(p.x, p.z)


## Wing angles (degrees about the vertical, right wing; the left mirrors it)
## for a state at time t: folded along the body, or held out to dry with now
## and then a shake.
static func wing_spread(s: State, t: float) -> float:
	var q := floorf(t * 15.0) / 15.0
	if s != State.DRY:
		return 0.0
	var shake := 8.0 * sin(q * 22.0) if fposmod(q, 6.0) < 0.6 else 0.0
	return DRY_SPREAD + shake


func _part(n: String, parent: Node3D, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = n
	node.position = pos
	parent.add_child(node)
	_parts[n] = node
	return node


func _mesh(parent: Node3D, kit: MeshKit) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _build() -> void:
	var k := MeshKit.new()
	for s: float in [-1.0, 1.0]:
		k.box("dark", Vector3(0.04 * s, 0.05, 0), Vector3(0.03, 0.1, 0.03), [])  # short legs
		k.box("dark", Vector3(0.04 * s, 0.005, -0.03), Vector3(0.07, 0.01, 0.09), [])  # webbed feet
	_mesh(self, k)
	# the body stands almost upright, leaning a little forward
	var body := _part("body", self, Vector3(0, 0.1, 0))
	var b := MeshKit.new()
	b.box("dark", Vector3(0, 0.19, 0.0), Vector3(0.16, 0.38, 0.17), [])
	b.box("dark", Vector3(0, 0.02, 0.14), Vector3(0.1, 0.04, 0.2), [])  # stiff tail, propping it up
	_mesh(body, b)
	body.rotation_degrees.x = -12.0
	var neck := _part("neck", body, Vector3(0, 0.37, -0.03))
	var n := MeshKit.new()
	n.box("dark", Vector3(0, 0.1, 0), Vector3(0.055, 0.2, 0.06), [])
	n.box("dark", Vector3(0, 0.22, -0.03), Vector3(0.07, 0.065, 0.11), [])  # head
	n.box("clay", Vector3(0, 0.205, -0.07), Vector3(0.05, 0.03, 0.03), [])  # bare yellow throat
	n.box("column", Vector3(0, 0.22, -0.13), Vector3(0.022, 0.022, 0.09), [])  # bill
	n.box("column", Vector3(0, 0.208, -0.172), Vector3(0.018, 0.02, 0.015), [])  # its hooked tip
	_mesh(neck, n)
	for s: float in [-1.0, 1.0]:
		var wing := _part("wing_l" if s < 0 else "wing_r", body, Vector3(0.085 * s, 0.32, 0.0))
		var w := MeshKit.new()
		# folded, the wing lies down the body's side; it opens by turning
		# out about the shoulder, ending held to the side like a cloak
		w.box("dark", Vector3(0, -0.14, 0.17), Vector3(0.025, 0.28, 0.36), [])
		w.box("dark", Vector3(0, -0.24, 0.33), Vector3(0.02, 0.14, 0.16), [])  # the ragged primaries at the tip
		_mesh(wing, w)


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	if cam != null and Vector2(global_position.x - cam.global_position.x, global_position.z - cam.global_position.z).length() > 80.0:
		return  # out in the haze: no work
	step(delta, cam.global_position if cam else Vector3(INF, 0, INF))


## One tick of its life; public so a test can run a bird without a camera.
func step(delta: float, threat: Vector3) -> void:
	_timer -= delta
	var near := Vector2(position.x - threat.x, position.z - threat.z).length() < SHY_DIST
	if near and not on_rock and state != State.WALK:
		state = State.WALK
		_target = Chicken.flee_target(position, threat, home, radius)
		_timer = 4.0
	match state:
		State.WALK:
			if _move(delta) or _timer <= 0.0:
				_choose()
		State.DRY:
			dried += delta
			if _timer <= 0.0:
				_choose()
		_:
			if _timer <= 0.0:
				_choose()
	_animate()


func _choose() -> void:
	var r := _rng.randf()
	if r < 0.45:
		state = State.DRY
		_timer = _rng.randf_range(8.0, 16.0)
	elif r < 0.65 or on_rock:
		state = State.PREEN if r < 0.8 else State.STAND
		_timer = _rng.randf_range(2.5, 5.0)
	else:
		state = State.WALK
		var a := _rng.randf_range(0, TAU)
		_target = Chicken.clamp_home(home + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(0.3, 1.0) * radius, home, radius)
		_timer = 8.0


func _move(delta: float) -> bool:
	var d := Vector3(_target.x - position.x, 0, _target.z - position.z)
	if d.length() < 0.05:
		return true
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), minf(1.0, delta * 8.0))
	var s := minf(d.length(), WALK_SPEED * delta)
	position += d.normalized() * s
	position = Chicken.clamp_home(position, home, radius)
	position.y = ground(position)
	walked += s
	return false


func _animate() -> void:
	var q := floorf(_t * 15.0) / 15.0
	var body: Node3D = _parts["body"]
	var neck: Node3D = _parts["neck"]
	var spread := wing_spread(state, _t)
	# the right wing swings out to +x about its shoulder, the left to -x
	(_parts["wing_r"] as Node3D).rotation_degrees = Vector3(0, spread, spread * 0.12)
	(_parts["wing_l"] as Node3D).rotation_degrees = Vector3(0, -spread, -spread * 0.12)
	match state:
		State.WALK:
			# a heavy waddle, rolling from foot to foot
			body.rotation_degrees = Vector3(-18.0, 0, sin(q * 9.0) * 9.0)
			neck.rotation_degrees = Vector3(-10.0 + sin(q * 9.0) * 4.0, 0, 0)
		State.DRY:
			# wings out, breast to the sun, the head turning slowly
			body.rotation_degrees = Vector3(-6.0, 0, 0)
			neck.rotation_degrees = Vector3(4.0, sin(q * 0.5) * 35.0, 0)
		State.PREEN:
			body.rotation_degrees = Vector3(-12.0, 0, 0)
			neck.rotation_degrees = Vector3(-115.0 + sin(q * 4.0) * 10.0, sin(q * 1.3) * 30.0, 0)
		_:
			body.rotation_degrees = Vector3(-12.0, 0, 0)
			neck.rotation_degrees = Vector3(0, sin(q * 0.8) * 50.0, 0)
