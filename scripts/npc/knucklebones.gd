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
##
## When the town's lamps come on (DayCycle.LAMPS_ON) the game is over: the two
## get up, walk home down the footpath to Myrto's house and sit by the hearth
## in the living room. Seen to happen, they walk; if the hour is already past
## dusk when the square is built (the prologue, the dream, a debug hour) they
## are simply there. Back under the threshold, they are playing again.

const HOUSE := preload("res://scripts/world/house.gd")

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
var _atm: Node
## True once the hour has been seen under dusk: only then do they walk home.
var _played := false
var _shells: Array[StaticBody3D] = []
## The two of them going home, or sitting there; empty while they play.
var _walkers: Array[Npc] = []
## The bones coming down on the stones, and the panel the player plays in.
var _clatter: AudioStreamPlayer3D
var _panel: CanvasLayer

## Home: from the square out through the parapet gap, down the footpath and in
## at the living room's door (House), world x/z on the flat at AGORA_H. Each
## child takes the same way, the second a little to the side of the first.
const HOME_ROUTE := [Vector2(30.0, 3.0), Vector2(26.0, 9.6), Vector2(26.0, 17.4), Vector2(22.9, 20.7), Vector2(22.9, 23.0)]
const ROUTE_SIDE := Vector2(0.4, 0.0)
## Where they sit, either side of the hearth, clear of the couch, the stool
## with the lamp on it and the way the player comes in to look at that lamp.
const HOME_SEATS := [Vector2(22.95, 25.75), Vector2(24.05, 25.05)]


## Whether, at this hour, the children are at home rather than on the square.
static func at_home(t: float) -> bool:
	return t >= DayCycle.LAMPS_ON


## The way home for child i, ending at its seat, world x/z.
static func home_route(i: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p: Vector2 in HOME_ROUTE:
		out.append(p + ROUTE_SIDE * float(i))
	out.append(HOME_SEATS[i])
	return out


## Facing the fire from a seat, as a yaw in degrees (Figure faces -Z).
static func seat_yaw(i: int) -> float:
	var d: Vector2 = HOUSE.HEARTH - HOME_SEATS[i]
	return rad_to_deg(atan2(-d.x, -d.y))


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
	# the bones come down on the stones between them, so that is where it is heard
	_clatter = AudioStreamPlayer3D.new()
	_clatter.name = "Clatter"
	_clatter.stream = preload("res://assets/audio/astragal.wav")
	_clatter.volume_db = -6.0
	_clatter.unit_size = 2.0
	_clatter.max_distance = 18.0
	_clatter.position.y = 0.05
	add_child(_clatter)


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
	_shells.append(shell)


func _process(delta: float) -> void:
	if _atm == null:
		_atm = _find_atmosphere()
	var hour: float = _atm.t if _atm != null else 0.0
	if at_home(hour):
		if _walkers.is_empty():
			_go_home(_played)
		return
	if not _walkers.is_empty():
		_come_out()
	_played = true
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
## there and not at the middle of the circle. The clatter comes a moment later,
## when they come down - each bone its own click, but one sound for the throw.
func _take_from_hand() -> void:
	var thrower := _joints[_landing_of % 2]
	var hand: Node3D = thrower.get("r_elbow")
	if hand == null:
		return
	var at := hand.global_position + hand.global_transform.basis.y * -0.26 * CHILD_SCALE
	for i in BONES:
		_from[i] = to_local(at)
	if _clatter != null:
		_clatter.pitch_scale = 0.95 + float(_landing_of % 3) * 0.05
		_clatter.play(FLIGHT * 0.55)


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


func _find_atmosphere() -> Node:
	var n := get_parent()
	while n != null:
		var a := n.get_node_or_null("Atmosphere")
		if a != null:
			return a
		n = n.get_parent()
	return null


## The game is over: the players on the square are put away and two walkers
## take their place, either at the start of the way home or already seated.
func _go_home(walk: bool) -> void:
	_show_game(false)
	for i in 2:
		var n: Npc = Npc.new()
		n.name = "HomeChild%d" % i
		n.talkable = false
		n.solid = false  # the route back up the footpath is the bot's too
		n.stops_for_player = false
		n.figure_scale = CHILD_SCALE
		n.body_mat = String(LOOKS[i]["cloth"])
		n.look = LOOKS[i]
		var route := home_route(i)
		var seat: Vector2 = route[route.size() - 1]
		var y := Topo.HOUSE_H
		if walk:
			var start := global_position + seat_spots()[i]
			n.pose = "stand"
			n.position = get_parent().to_local(Vector3(start.x, y, start.z))
			var pts := PackedVector3Array()
			var pauses := PackedFloat32Array()
			var poses := PackedStringArray()
			var faces := PackedFloat32Array()
			for k in route.size():
				pts.append(Vector3(route[k].x - start.x, 0, route[k].y - start.z))
				var last := k == route.size() - 1
				pauses.append(1.0e9 if last else 0.0)  # there for the night
				poses.append("sit" if last else "walk")
				faces.append(seat_yaw(i) if last else NAN)
			n.patrol = pts
			n.patrol_pauses = pauses
			n.patrol_poses = poses
			n.patrol_faces = faces
			n.patrol_speed = 0.5
		else:
			n.pose = "sit"
			n.position = get_parent().to_local(Vector3(seat.x, y, seat.y))
			n.rotation.y = deg_to_rad(seat_yaw(i))
		get_parent().add_child(n)
		_walkers.append(n)


## Morning again (or the hour turned back): the walkers go, the game comes out.
func _come_out() -> void:
	for n in _walkers:
		n.queue_free()
	_walkers.clear()
	_show_game(true)


func _show_game(on: bool) -> void:
	for b in _bodies:
		b.visible = on
	for b in _bones:
		b.visible = on
	for s in _shells:
		s.collision_layer = 3 if on else 0


## The two going home or sitting there; empty while they play.
func walkers() -> Array[Npc]:
	return _walkers


## The two children, for tests and for anything that wants to look at them.
func children() -> Array[Node3D]:
	return _bodies


## The game with them comes later; until then the crosshair skips the children.
func can_interact() -> bool:
	# nobody plays knucklebones in the dark, and the children are indoors by then
	return not Knucklebones.at_home(Game.time_target())


func get_prompt() -> String:
	return tr("UI_ASTRAGAL_PLAY")


## E at the children sits the player down to a throw of their own: five bones,
## three throws, higher sum takes the throw.
func interact() -> void:
	if _panel != null and is_instance_valid(_panel):
		return
	_panel = preload("res://scripts/ui/astragal_panel.gd").new()
	_panel.name = "AstragalPanel"
	get_tree().current_scene.add_child(_panel)
	_panel.closed.connect(func() -> void: _panel = null)
	_panel.open()
