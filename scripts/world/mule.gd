class_name Mule
extends Node3D
## A yard mule, built from boxes the way the dog and the hens are: a low barrel
## on four legs, a neck carried forward, long ears and a tail that never stops.
## It walks its pen from one tuft of grass to the next, head down to graze, and
## now and then goes to the trough to drink. No collider, like the hens: it is
## weather, not furniture. Pose and gait are stepped at 15 fps.

const BODY_Y := 1.12
## The rump ends at z = 0.65; the tail hangs just behind it, not inside it.
const TAIL_Z := 0.68

enum State { GRAZE, WALK, DRINK }
const WALK_SPEED := 0.45
const TURN_SPEED := 2.2  # rad/s
## From the middle of the body to the muzzle: where the head reaches.
const REACH := 0.95

## Where its middle may go (x, z), the tufts it grazes and where the trough's
## water is; set by whoever builds the yard.
var bounds := Rect2(-1, -1, 2, 2)
var tufts: Array[Vector2] = []
var drink_at := Vector2.INF
var state := State.GRAZE
var grazed := 0
var drunk := 0
var _target := Vector2.ZERO
var _face := NAN
var _left := 3.0
var _rng := RandomNumberGenerator.new()
var _head: Node3D
var _tail: Node3D
var _ear_l: Node3D
var _legs: Array[Node3D] = []
var _gait := 0.0
var _t := 0.0


func _ready() -> void:
	add_to_group(&"mule")
	_t = randf() * 4.0
	_rng.seed = 731
	var kit := MeshKit.new()
	# barrel low and long, with a deeper chest and a rounded croup
	kit.box("fur", Vector3(0, BODY_Y, 0.0), Vector3(0.46, 0.46, 1.05), [])
	kit.box("fur", Vector3(0, BODY_Y + 0.02, -0.5), Vector3(0.42, 0.44, 0.36), [])
	kit.box("fur", Vector3(0, BODY_Y, 0.5), Vector3(0.4, 0.4, 0.3), [])
	add_child(kit.build("Mule"))
	# four legs on hips of their own, so it can walk; dark hooves
	for sx: float in [-0.15, 0.15]:
		for sz: float in [-0.42, 0.44]:
			var hip := Node3D.new()
			hip.position = Vector3(sx, 0.97, sz)
			add_child(hip)
			var lk := MeshKit.new()
			lk.box("fur", Vector3(0, -0.47, 0), Vector3(0.13, 0.95, 0.15), [])
			lk.box("dark", Vector3(0, -0.94, 0), Vector3(0.15, 0.06, 0.17), [])
			var lm := MeshInstance3D.new()
			lm.mesh = lk.commit()
			hip.add_child(lm)
			_legs.append(hip)
	# neck and head on a pivot at the withers, so the head can hang into the hay
	_head = Node3D.new()
	_head.position = Vector3(0, BODY_Y + 0.16, -0.58)
	add_child(_head)
	var hk := MeshKit.new()
	hk.box("fur", Vector3(0, 0.1, -0.06), Vector3(0.2, 0.42, 0.24), [])  # neck
	hk.box("hair", Vector3(0, 0.14, -0.19), Vector3(0.06, 0.34, 0.08), [])  # mane down the back of the neck
	hk.box("fur", Vector3(0, 0.24, -0.28), Vector3(0.17, 0.2, 0.36), [])  # skull
	hk.box("fur", Vector3(0, 0.18, -0.48), Vector3(0.13, 0.14, 0.16), [])  # muzzle
	hk.box("dark", Vector3(0, 0.16, -0.56), Vector3(0.09, 0.08, 0.04), [])  # nose
	hk.box("dark", Vector3(0.075, 0.26, -0.3), Vector3(0.03, 0.03, 0.03), [])  # eyes
	hk.box("dark", Vector3(-0.075, 0.26, -0.3), Vector3(0.03, 0.03, 0.03), [])
	hk.box("fur", Vector3(0.06, 0.42, -0.2), Vector3(0.05, 0.26, 0.05), [])  # ears, long as a mule's
	hk.box("fur", Vector3(-0.06, 0.42, -0.2), Vector3(0.05, 0.26, 0.05), [])
	var hm := MeshInstance3D.new()
	hm.mesh = hk.commit()
	_head.add_child(hm)
	_ear_l = _head
	# tail on its own pivot
	_tail = Node3D.new()
	# on the rear face of the rump, not buried in it
	_tail.position = Vector3(0, BODY_Y + 0.12, TAIL_Z)
	add_child(_tail)
	var tk := MeshKit.new()
	tk.box("hair", Vector3(0, -0.28, 0.01), Vector3(0.055, 0.56, 0.055), [])
	tk.box("dark", Vector3(0, -0.6, 0.02), Vector3(0.1, 0.14, 0.1), [])
	var tm := MeshInstance3D.new()
	tm.mesh = tk.commit()
	_tail.add_child(tm)


## The next place to go: mostly a tuft, sometimes the trough. Returns where
## the head should end up; the body stops REACH short of it.
func _choose() -> void:
	if drink_at != Vector2.INF and (tufts.is_empty() or _rng.randf() < 0.25):
		state = State.DRINK
		_target = drink_at
	else:
		state = State.WALK
		var t: Vector2 = tufts[_rng.randi_range(0, tufts.size() - 1)] if not tufts.is_empty() \
				else Vector2(_rng.randf_range(bounds.position.x, bounds.end.x), _rng.randf_range(bounds.position.y, bounds.end.y))
		_target = t


func _process(delta: float) -> void:
	_t += delta
	step(delta)
	var q := floorf(_t * 15.0) / 15.0
	var walking := state == State.WALK or (state == State.DRINK and _left < 0.0)
	# head down into the grass or the water while it stands; carried while it walks
	var down := -14.0 if walking else (-48.0 if state == State.GRAZE else -42.0)
	var chew := 0.0 if walking else sin(q * 5.0) * 4.0
	_head.rotation_degrees.x = down + chew + (sin(q * 0.8) * 4.0 if walking else 0.0)
	_tail.rotation_degrees.z = sin(q * 2.1) * 14.0
	# diagonal pairs swing together, as a mule walks
	var swing := sin(floorf(_gait * 15.0) / 15.0 * 7.0) * 22.0 if walking else 0.0
	for i in _legs.size():
		var pair := 1.0 if i == 0 or i == 3 else -1.0
		_legs[i].rotation_degrees.x = swing * pair


## One tick of the mule's day: walk to the target, then graze or drink a while.
## Kept apart from the animation so a test can run it without a scene.
func step(delta: float) -> void:
	var here := Vector2(position.x, position.z)
	var moving := state == State.WALK or (state == State.DRINK and _left < 0.0)
	if not moving:
		_left -= delta
		if _left <= 0.0:
			_choose()
			_left = -1.0  # on the way
		return
	var to := _target - here
	if to.length() <= REACH:
		# arrived: the head is over the grass or the water
		if state == State.DRINK:
			drunk += 1
			_left = _rng.randf_range(4.0, 7.0)
		else:
			state = State.GRAZE
			grazed += 1
			_left = _rng.randf_range(5.0, 10.0)
		return
	_gait += delta
	var want := atan2(-to.x, -to.y)  # the head is at -z
	if is_nan(_face):
		_face = rotation.y
	_face = rotate_toward(_face, want, TURN_SPEED * delta)
	rotation.y = _face
	# walk only once roughly facing the way, so it does not slide sideways
	if absf(angle_difference(_face, want)) < 0.6:
		var fwd := Vector2(-sin(_face), -cos(_face))
		var next := here + fwd * WALK_SPEED * delta
		next.x = clampf(next.x, bounds.position.x, bounds.end.x)
		next.y = clampf(next.y, bounds.position.y, bounds.end.y)
		position.x = next.x
		position.z = next.y
		position.y = Topo.surface(next.x, next.y)
