class_name Knucklebones
extends Node3D
## Two children playing knucklebones on the square: they sit facing each other
## with five astragals between them, one gathers the bones, cups them in both
## hands and throws, and while the bones lie where they landed the other child
## takes a turn. Nobody is talkable yet - `can_interact()` is false, so the
## crosshair leaves them alone - but the bones are already dealt out for the
## game the player will later join.
##
## The whole thing runs off one clock: throw `n` happens at n * TURN + RELEASE,
## so the children alternate without a state machine, and each bone knows from
## the clock alone whether it is in a hand, in the air, or lying on the stones.
## Everything steps on 1/15 s, the clock the rest of the city moves on.

const CHILD_SCALE := 0.62
## How far each child sits from the middle, along the local x.
const SEAT_GAP := 0.62
## How they look: cropped hair and a plain tunic, curly hair and an ochre one.
## Both in short tunics (Figure's default for anyone who is not a woman).
const LOOKS := [
	{"beard": 0, "hair": 0, "cloth": "chiton"},
	{"beard": 0, "hair": 1, "cloth": "chiton_ochre"},
]

const BONES := 5
## One child's turn, in seconds: the other waits this long before gathering.
const TURN := 3.6
## Into a turn: the hand is down on the bones, and up with them at RELEASE.
const GATHER := 0.9
const RELEASE := 1.9
## How long a bone is in the air, and the extra wait per bone so they fan out.
const FLIGHT := 0.55
const STAGGER := 0.05
## How far from the middle a bone may come down.
const SPREAD := 0.34
## A bone lies flat on the paving, half its thickness up.
const REST_Y := 0.03
const BONE_LEN := 0.09
## How high the bones arc on the way.
const ARC := 0.4

var _joints: Array[Dictionary] = []
var _bodies: Array[Node3D] = []
var _bones: Array[MeshInstance3D] = []
## Where this bone was at the moment of the last release (the thrower's hand).
var _from: Array[Vector3] = []
## The throw whose landing spots the bones are flying to / lying on now.
var _landing_of := -99
var _t := 0.0


## Where the two children sit, as local offsets from the middle.
static func seat_spots() -> Array[Vector3]:
	return [Vector3(-SEAT_GAP, 0, 0), Vector3(SEAT_GAP, 0, 0)]


## Where bone `i` comes down after throw `n`, as a local offset. The five share
## the circle out between them - one bone every 72 degrees, jittered, and the
## rings staggered - so no two ever land on one another, and the middle stays
## clear for the hand that gathers them.
static func bone_home(n: int, i: int) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8100 + n * 97 + i * 13
	var a := TAU * float(i) / float(BONES) + rng.randf_range(-0.3, 0.3) + float(n) * 0.7
	var r := minf(SPREAD * sqrt((float(i) + 0.5) / float(BONES)) + rng.randf_range(-0.02, 0.02), SPREAD)
	return Vector3(cos(a) * r, REST_Y, sin(a) * r)


func _ready() -> void:
	for i in 2:
		_child(i)
	var mesh := _bone_mesh()
	for i in BONES:
		var bone := MeshInstance3D.new()
		bone.mesh = mesh
		bone.name = "Astragal%d" % i
		add_child(bone)
		_bones.append(bone)
		_from.append(Vector3.ZERO)
		_set_bone(0, i)


func _bone_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	# a knuckle is a bar with two knobs, not a die: four flat faces and no six
	kit.box("bone", Vector3.ZERO, Vector3(BONE_LEN, 0.042, 0.048), [])
	for s: float in [1.0, -1.0]:
		kit.box("bone", Vector3(s * BONE_LEN * 0.5, 0.0, 0.0), Vector3(0.032, 0.056, 0.056), [])
		kit.box("bone", Vector3(s * BONE_LEN * 0.34, 0.02, 0.0), Vector3(0.05, 0.03, 0.03), [])
	return kit.commit()


func _child(i: int) -> void:
	var body := Node3D.new()
	body.name = "Child%d" % i
	body.scale = Vector3.ONE * CHILD_SCALE
	body.position = seat_spots()[i]
	# Figure faces -Z: turn each child to look at the other one across the bones
	body.rotation.y = deg_to_rad(-90.0 if i == 0 else 90.0)
	add_child(body)
	var joints := Figure.build(body, "chiton", LOOKS[i])
	Figure.apply_pose(joints, "sit")
	_joints.append(joints)
	_bodies.append(body)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 0.62, 0.5)
	cs.shape = shape
	cs.position = Vector3(0, 0.31, 0)
	var shell := StaticBody3D.new()
	shell.name = "Seat%d" % i
	shell.collision_layer = 3
	shell.position = seat_spots()[i]
	shell.add_child(cs)
	add_child(shell)


func _process(delta: float) -> void:
	_t += delta
	var t := floorf(_t * 15.0) / 15.0
	var turn := floori(t / TURN)
	var into := t - float(turn) * TURN
	for i in 2:
		var throwing := turn % 2 == i
		var extra := _toss_extra(into) if throwing else _waiting(t, i)
		Figure.apply_pose(_joints[i], "sit", extra)
	var handed := into >= GATHER and into < RELEASE
	for i in BONES:
		_place_bone(i, t, handed)


## The thrower's arms, added on top of the sitting pose: down to the stones,
## up with the bones to the chest, out in a sweep, then back to watching them.
func _toss_extra(k: float) -> Dictionary:
	if k < GATHER:
		return _mix(REST, REACH, smoothstep(0.0, 1.0, k / GATHER))
	if k < GATHER + 0.55:
		return _mix(REACH, CUP, (k - GATHER) / 0.55)
	if k < RELEASE:
		return _mix(CUP, FLING, (k - GATHER - 0.55) / (RELEASE - GATHER - 0.55))
	if k < 2.9:
		return _mix(FLING, WATCH, (k - RELEASE) / (2.9 - RELEASE))
	return _mix(WATCH, REST, (k - 2.9) / (TURN - 2.9))


## The child who waits: chin down on the bones, a little sway, now and then a
## glance at the other one.
func _waiting(t: float, i: int) -> Dictionary:
	var sway := sin(t * 1.3 + i) * 3.0
	return {"head": Vector3(-16.0 + sin(t * 0.9 + i * 2.0) * 5.0, sway, 0.0),
		"chest": Vector3(sway * 0.4, 0, 0)}


## Where one bone is at time t: in a hand (hidden), in the air, or on the stones.
func _place_bone(i: int, t: float, handed: bool) -> void:
	var bone := _bones[i]
	if handed:
		bone.visible = false
		return
	# the last throw that has already left the hand; before the first one the
	# bones are simply lying where that throw will put them
	var n := 0
	if t >= RELEASE:
		n = floori((t - RELEASE) / TURN)
	_set_bone(n, i)
	bone.visible = true
	var start := float(n) * TURN + RELEASE
	var air := FLIGHT + float(i) * STAGGER
	if t < start or t >= start + air:
		return
	if _landing_of != n:
		_landing_of = n
		_take_from_hand()
	var k := (t - start) / air
	bone.position = _from[i].lerp(bone_home(n, i), k) + Vector3.UP * (ARC * 4.0 * k * (1.0 - k))
	bone.rotation_degrees = Vector3(360.0 * k * 2.0, 47.0 * float(i), 130.0 * k)


## The bones have just left the hand: remember where it was, so the arc starts
## there and not at the middle of the circle.
func _take_from_hand() -> void:
	var thrower := _joints[_landing_of % 2]
	var hand: Node3D = thrower.get("r_elbow")
	if hand == null:
		return
	var at := hand.global_position + hand.global_transform.basis.y * -0.26 * CHILD_SCALE
	for i in BONES:
		_from[i] = to_local(at)


## Finished bones get a yaw of their own, so five of them never lie in a row.
func _set_bone(n: int, i: int) -> void:
	var home := bone_home(n, i)
	_bones[i].position = home
	_bones[i].rotation_degrees = Vector3(0, 23.0 * float(i) + float(n) * 7.0, 0)


## The pose angles of a figure whose arms do nothing but sit in its lap.
const REST := {}
## Reaching down between the knees: the chest folds, the throwing arm straightens.
const REACH := {"chest": Vector3(-34, 0, 0), "head": Vector3(-10, 0, 0),
	"r_shoulder": Vector3(-14, 0, -6), "r_elbow": Vector3(-50, 0, 0),
	"l_shoulder": Vector3(-8, 0, 6), "l_elbow": Vector3(-40, 0, 0)}
## Both hands at the chest, cupping the bones.
const CUP := {"chest": Vector3(2, 0, 0), "head": Vector3(6, 0, 0),
	"r_shoulder": Vector3(-4, 0, -8), "r_elbow": Vector3(40, 0, 0), "l_elbow": Vector3(20, 0, 0)}
## The sweep: the arm is thrown forward and up, the hand opens at RELEASE.
const FLING := {"chest": Vector3(-10, 0, 0), "head": Vector3(-4, 0, 0),
	"r_shoulder": Vector3(55, 0, -10), "r_elbow": Vector3(-40, 0, 0)}
## Leaning over the bones to see what came up.
const WATCH := {"chest": Vector3(-8, 0, 0), "head": Vector3(-16, 0, 0),
	"r_shoulder": Vector3(6, 0, 0), "r_elbow": Vector3(-6, 0, 0)}


## A pose between two others: every joint either one names, missing ones reading
## as zero, so the two can be blended without filling the dictionaries in.
static func _mix(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	var out := {}
	for name: String in ["chest", "head", "l_shoulder", "r_shoulder", "l_elbow", "r_elbow"]:
		var from: Vector3 = a.get(name, Vector3.ZERO)
		var to: Vector3 = b.get(name, Vector3.ZERO)
		var v := from.lerp(to, clampf(u, 0.0, 1.0))
		if v != Vector3.ZERO:
			out[name] = v
	return out


## The two children, for tests and for anything that wants to look at them.
func children() -> Array[Node3D]:
	return _bodies


## The game with them comes later; until then the crosshair skips the children.
func can_interact() -> bool:
	return false


func interact() -> void:
	pass


func get_prompt() -> String:
	return ""
