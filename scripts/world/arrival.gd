class_name Arrival
extends District
## A second merchantman comes in to the pier during the day, while the Swallow
## lies where she always lies on its north side. Once the afternoon is on
## (INBOUND_FROM) she shows far out on the strait and sails in; off the harbour
## she shortens sail and lies to until someone is at the shore to see her come
## alongside (or until BERTH_BY, so she is in before dusk whoever watches). Then
## she glides in to the south side of the pier with her canvas coming in, her
## lines go ashore and are hauled taut, the gangway comes down, and two dockers
## carry her amphorae to the beach by the pier's root while a sailor hands them
## over the rail. By lamplight the dockers go home; the ship stays.
##
## Everything is a pure function of two numbers: the seconds since she was
## sighted and the second she was called in (pose()). No physics, no state but
## those two clocks, which advance only in the live day (not in the prologue,
## not in the dream). A world that starts with the day already past her sighting
## (a restored walk, a shot at a set hour) has her moored at once.

const NPC := preload("res://scripts/npc/npc.gd")
const HARBOUR := preload("res://scripts/world/harbour.gd")

## Sighted from this hour (about the third find), in by this one at the latest.
const INBOUND_FROM := 0.15
const BERTH_BY := 0.55
## Called in when the player comes this close to her berth.
const CALL_R := 55.0
## Far out in the haze, and where she lies to off the harbour, on the line of
## her berth so the last of it is straight in.
const FAR := Vector3(420.0, 0.0, 30.0)
const STANDOFF := Vector3(136.0, 0.0, -1.0)
## Alongside the pier's south side (+z), bow to the land: her keel this far off the
## planks' edge, like the Swallow on the other side.
const BERTH_X := 84.0
const BERTH_YAW := 180.0
const SHIP_GAP := 3.7
const WATERLINE := HARBOUR.WATERLINE
## Seconds: sailing in, the glide alongside, the lines going ashore and being
## hauled taut, the gangway coming down, and unloading from then on.
const SAIL_IN := 200.0
const GLIDE := 45.0
const THROW := 6.0
const TAUT := 6.0
const GANGWAY_AT := GLIDE + THROW + 4.0
const GANGWAY_T := 6.0
const UNLOAD_AT := GANGWAY_AT + GANGWAY_T + 2.0
## How much she rolls with the sea under way, and alongside with her lines on.
const ROLL_SAILING := 1.0
const ROLL_MOORED := 0.5
## The jolt when her lines come taut: she surges along the pier and settles.
const SURGE := 0.35
## The lines: slack as they land, at the harbour's sag once hauled in.
const SLACK := 1.1
## Where the lines are made fast: two bollards on the south edge, clear of the
## cargo there and of the lantern post at the end.
const BOLLARDS_X := [76.4, 90.0]
## Where the gangway comes down onto the planks (x), between the splicer and the
## lantern post; the dockers take the jars from the rail there.
const GANGWAY_X := 87.5
## A docker's round: [x, z, pose, pause s, facing yaw deg or NAN]. A jar from
## the sailor at the rail, along the pier's south side behind the cargo and the
## carrier's lane, off the planks at the root and down to the stack on the beach.
const DOCKER_ROUTE := [
	[87.5, -5.15, "pick", 2.2, 180.0],
	[86.6, -5.7, "walk", 0.0, NAN],
	[64.4, -5.7, "walk", 0.0, NAN],
	[63.9, -4.6, "walk", 0.0, NAN],
	[64.3, -3.75, "pick", 1.6, 180.0],
	[63.9, -4.6, "walk", 0.0, NAN],
	[64.4, -5.7, "walk", 0.0, NAN],
	[86.6, -5.7, "walk", 0.0, NAN],
]
const DOCKER_TAKE := 0
const DOCKER_DROP := 4
## The two dockers: looks and where on the round each starts.
const DOCKERS := [
	[{"beard": 2, "hair": 1, "cloth": "chiton_ochre"}, 0],
	[{"beard": 0, "hair": 3, "cloth": "chiton_dark"}, 4],
]
## The jars as they come ashore, on the beach behind the drop point.
const STACK := Vector2(64.3, -3.1)
const STACK_SPOTS := [
	Vector2(-0.3, 0.0), Vector2(0.05, 0.05), Vector2(0.4, -0.02),
	Vector2(-0.15, 0.35), Vector2(0.22, 0.38), Vector2(0.55, 0.3),
	Vector2(-0.4, 0.4), Vector2(0.0, 0.7),
]
## Timbers groan now and then once she is alongside: a window of this many
## seconds, and in every second window.
const CREAK_EVERY := 7.0

enum Stage { HIDDEN, INBOUND, LYING_TO, BERTHING, MOORED }

var _ship: Node3D
var _lines: MeshInstance3D
var _gangway: Node3D
var _gangway_len := 0.0
var _atm: Node
var _decided := false
## Seconds since she was sighted (-1 before), and the second she was called in.
var since := -1.0
var called := -1.0
var _dockers: Array[Npc] = []
var _stack: Array[Node3D] = []
var _stacked := 0
var _hand_jar: Node3D
var _audio: AudioStreamPlayer3D
var _creak: AudioStreamPlayer3D
var _line_step := -1
var _furl := -1.0
var _t := 0.0


static func berth() -> Vector3:
	return Vector3(BERTH_X, WATERLINE, Topo.PIER_Z + Topo.PIER_HALF + SHIP_GAP)


## Where she is and how, `s` seconds after she was sighted and `c` the second
## she was called in (-1: not yet). Keys: stage, pos (y is her waterline),
## yaw (deg), furl, roll, surge (m along her keel), lines (0..1 thrown), taut,
## gangway (0..1 down), unload (seconds, -1 before).
static func pose(s: float, c: float) -> Dictionary:
	var out := {"stage": Stage.HIDDEN, "pos": FAR + Vector3(0, WATERLINE, 0), "yaw": course_yaw(),
			"furl": 0.0, "roll": ROLL_SAILING, "surge": 0.0, "lines": 0.0, "taut": 0.0,
			"gangway": 0.0, "unload": -1.0}
	if s < 0.0:
		return out
	if s < SAIL_IN:
		var k := s / SAIL_IN
		out.stage = Stage.INBOUND
		out.pos = FAR.lerp(STANDOFF, smoothstep(0.0, 1.0, k)) + Vector3(0, WATERLINE, 0)
		out.yaw = rad_to_deg(lerp_angle(deg_to_rad(course_yaw()), deg_to_rad(BERTH_YAW), smoothstep(0.85, 1.0, k)))
		# she shortens sail over the last of the run in
		out.furl = 0.5 * smoothstep(0.8, 1.0, k)
		return out
	if c < 0.0 or s < c:
		out.stage = Stage.LYING_TO
		out.pos = STANDOFF + Vector3(0, WATERLINE, 0)
		out.yaw = BERTH_YAW
		out.furl = 0.5
		return out
	var b := s - c
	out.yaw = BERTH_YAW
	if b < GLIDE:
		var k := b / GLIDE
		out.stage = Stage.BERTHING
		# eases in: way coming off her all the glide, none left at the berth
		out.pos = (STANDOFF + Vector3(0, WATERLINE, 0)).lerp(berth(), 1.0 - pow(1.0 - k, 2.0))
		out.furl = lerpf(0.5, 1.0, smoothstep(0.0, 0.6, k))
		out.roll = lerpf(ROLL_SAILING, ROLL_MOORED, k)
		return out
	out.stage = Stage.MOORED
	out.pos = berth()
	out.furl = 1.0
	out.roll = ROLL_MOORED
	out.lines = clampf((b - GLIDE) / THROW, 0.0, 1.0)
	out.taut = clampf((b - GLIDE - THROW) / TAUT, 0.0, 1.0)
	var tb := b - GLIDE - THROW - TAUT
	if tb > 0.0:
		out.surge = SURGE * exp(-tb / 1.6) * sin(tb * 2.4)
	out.gangway = clampf((b - GANGWAY_AT) / GANGWAY_T, 0.0, 1.0)
	out.unload = b - UNLOAD_AT if b >= UNLOAD_AT else -1.0
	return out


## Her heading on the run in from FAR (deg about y; the model's bow is +x).
static func course_yaw() -> float:
	var d := STANDOFF - FAR
	return rad_to_deg(atan2(-d.z, d.x))


## Moments worth a sound between two berthing clocks: the hail as she comes
## in, each line landing, the gangway on the planks.
static func events(b0: float, b1: float) -> Array[String]:
	var out: Array[String] = []
	for e: Array in [["hail", GLIDE - 14.0], ["line", GLIDE + 0.5], ["line", GLIDE + 3.0], ["gangway", GANGWAY_AT + GANGWAY_T]]:
		if b0 < float(e[1]) and b1 >= float(e[1]):
			out.append(e[0])
	return out


## Where each line runs: [bollard (world), rail (in the ship's frame)]. She lies
## bow to the land, so her pier side is her own +z and her x runs against the
## world's.
static func line_ends() -> Array:
	var out := []
	var z := Topo.PIER_Z + Topo.PIER_HALF - 0.25
	for bx: float in BOLLARDS_X:
		var lx := -(bx - BERTH_X)
		lx += -0.8 if lx > 0.0 else 0.8
		out.append([Vector3(bx, Topo.PIER_H + 0.3, z), Vector3(lx, 2.25, ship_hull_half_beam(lx) - 0.05)])
	return out


## The gangway's two ends at the berth: on the planks, and on her rail.
static func gangway_ends() -> Array:
	var foot := Vector3(GANGWAY_X, Topo.PIER_H + 0.02, Topo.PIER_Z + Topo.PIER_HALF - 0.3)
	var lx := -(GANGWAY_X - BERTH_X)
	var rail := berth() + Vector3(-lx, 2.27, -(ship_hull_half_beam(lx) - 0.4))
	return [foot, rail]


## How many jars are on the beach after this many seconds of unloading, if the
## dockers keep their pace (a restored walk lays out what they would have done).
static func stacked_by(unload: float) -> int:
	if unload < 0.0:
		return 0
	return mini(STACK_SPOTS.size(), floori(unload / 30.0))


static func at_work(hour: float, unload: float) -> bool:
	return unload >= 0.0 and hour < DayCycle.LAMPS_ON


static func docker_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for r: Array in DOCKER_ROUTE:
		out.append(Vector2(r[0], r[1]))
	return out


func _ready() -> void:
	add_to_group(&"arrival")
	_atm = get_parent().get_node_or_null("Atmosphere")
	_ship = place("ship", FAR, BERTH_YAW, Vector3.ONE)
	_ship.name = "Arriving"
	for g: GeometryInstance3D in _ship.find_children("*", "GeometryInstance3D", true, false):
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	laid_ship_deck(_ship)
	_ship.visible = false
	_deck_crew()
	_lines = MeshInstance3D.new()
	_lines.name = "ArrivalLines"
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lines)
	var kit := MeshKit.new()
	for bx: float in BOLLARDS_X:
		var p := Vector3(bx, Topo.PIER_H, Topo.PIER_Z + Topo.PIER_HALF - 0.25)
		kit.lathe("wood", PackedVector2Array([Vector2(0.14, 0.0), Vector2(0.12, 0.35), Vector2(0.17, 0.42)]), 7,
				p, 1.0, false, "wood", true)
		kit.add_collider(p + Vector3(0, 0.2, 0), Vector3(0.34, 0.4, 0.34))
	add_child(kit.build("ArrivalBollards"))
	_build_gangway()
	for i in STACK_SPOTS.size():
		var o: Vector2 = STACK + STACK_SPOTS[i]
		var jar := place("amphora", Vector3(o.x, Topo.terrain(o.x, o.y), o.y), i * 47.0, Vector3.ONE * 0.85)
		jar.visible = false
		_stack.append(jar)
	for i in DOCKERS.size():
		_docker(i)
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 6.0
	_audio.max_distance = 70.0
	_ship.add_child(_audio)
	_creak = AudioStreamPlayer3D.new()
	_creak.stream = preload("res://assets/audio/creak.wav")
	_creak.unit_size = 3.0
	_creak.max_distance = 25.0
	_creak.volume_db = -8.0
	_creak.position = Vector3(0, 1.5, 0)
	_ship.add_child(_creak)
	Game.state_restored.connect(_restored)
	_apply(pose(since, called), 0.0)


## A sailor on her deck at the gangway, who hands the jars down, and one in the
## bow, who throws the bow line. They ride with her.
func _deck_crew() -> void:
	var lx := -(GANGWAY_X - BERTH_X)
	var hand: Npc = NPC.new()
	hand.npc_id = "deckhand"
	hand.name_key = "NPC_SAILOR_NAME"
	hand.pose = "pick"
	hand.body_mat = "chiton"
	hand.talkable = false
	hand.solid = false
	hand.look = {"beard": 1, "hair": 2, "cloth": "chiton"}
	hand.position = Vector3(lx, SHIP_DECK_Y, ship_deck_half_beam(lx) - 0.45)
	hand.rotation.y = PI  # faces her +z, the pier
	_ship.add_child(hand)
	var jar := Props.instance("amphora")
	jar.position = Vector3(0, 0.05, -0.32)
	jar.scale = Vector3.ONE * 0.75
	(hand.joints["chest"] as Node3D).add_child(jar)
	_hand_jar = jar
	var bow: Npc = NPC.new()
	bow.npc_id = "bowman"
	bow.name_key = "NPC_SAILOR_NAME"
	bow.pose = "stand"
	bow.body_mat = "chiton_dark"
	bow.talkable = false
	bow.solid = false
	bow.look = {"beard": 0, "hair": 1, "cloth": "chiton_dark"}
	bow.position = Vector3(5.6, SHIP_DECK_Y, 0.5)
	bow.rotation.y = PI  # watching the pier come up on her +z side
	_ship.add_child(bow)


func _build_gangway() -> void:
	var e := gangway_ends()
	_gangway_len = (e[0] as Vector3).distance_to(e[1])
	var kit := MeshKit.new()
	# along -z from the rail end (the pivot), so a turn of the node swings it down
	kit.box("wood", Vector3(0, 0, -_gangway_len / 2.0), Vector3(0.55, 0.06, _gangway_len + 0.2), [])
	for i in 4:
		kit.box("bark", Vector3(0, 0.04, -0.4 - i * 0.45), Vector3(0.55, 0.03, 0.05), [])
	_gangway = kit.build("ArrivalGangway")
	_gangway.visible = false
	add_child(_gangway)


func _docker(i: int) -> void:
	var spec: Array = DOCKERS[i]
	var start: int = spec[1]
	var n: Npc = NPC.new()
	n.name = "Docker%d" % i
	n.npc_id = "docker%d" % i
	n.name_key = "NPC_SAILOR_NAME"
	n.look = spec[0]
	n.pose = "stand"
	n.talkable = false
	n.solid = false
	n.follow_ground = true
	var r: Array = DOCKER_ROUTE[start]
	n.position = Vector3(r[0], Topo.surface(r[0], r[1]), r[1])
	set_docker_round(n, start)
	add_child(n)
	var jar := Props.instance("amphora")
	jar.position = Vector3(0, 0.05, -0.32)
	jar.scale = Vector3.ONE * 0.75
	(n.joints["chest"] as Node3D).add_child(jar)
	jar.visible = start != DOCKER_DROP
	n.carrying = jar.visible
	n.reached.connect(func(k: int) -> void:
		var at := posmod(k + start, DOCKER_ROUTE.size())
		if at == DOCKER_TAKE:
			jar.visible = true
			n.carrying = true
		elif at == DOCKER_DROP:
			jar.visible = false
			n.carrying = false
			_set_stacked(_stacked + 1))
	n.visible = false
	n.process_mode = Node.PROCESS_MODE_DISABLED
	_dockers.append(n)


## A docker's round as a patrol, starting at `start`. Static so the test can walk it.
static func set_docker_round(c: Npc, start := 0) -> void:
	var n := DOCKER_ROUTE.size()
	var r0: Array = DOCKER_ROUTE[start]
	var home := Vector3(r0[0], 0, r0[1])
	var pts := PackedVector3Array()
	var poses := PackedStringArray()
	var pauses := PackedFloat32Array()
	var faces := PackedFloat32Array()
	for k in n:
		var r: Array = DOCKER_ROUTE[(start + k) % n]
		pts.append(Vector3(r[0], 0, r[1]) - home)
		poses.append(r[2])
		pauses.append(r[3])
		faces.append(r[4])
	c.patrol = pts
	c.patrol_poses = poses
	c.patrol_pauses = pauses
	c.patrol_faces = faces
	c.patrol_speed = 0.8
	c.stops_for_player = false
	c.carry_pose = "carry"


func _set_stacked(n: int) -> void:
	_stacked = clampi(n, 0, _stack.size())
	for i in _stack.size():
		_stack[i].visible = i < _stacked


func _hour() -> float:
	return float(_atm.t) if _atm != null else Game.time_target()


## Past her sighting already: she lies alongside, the jars of a working day ashore.
func _moored_already() -> void:
	called = SAIL_IN
	since = SAIL_IN + UNLOAD_AT + 30.0 * STACK_SPOTS.size()
	_set_stacked(stacked_by(since - called - UNLOAD_AT))
	_apply(pose(since, called), 0.0)


## Puts her at a moment of her day: shots and QA scenarios, which cannot wait
## the minutes she takes to come in.
func set_clock(s: float, c := -1.0) -> void:
	_decided = true
	since = s
	called = c
	var p := pose(since, called)
	_set_stacked(stacked_by(float(p.unload)))
	_apply(p, 0.0)


func stage() -> int:
	return int(pose(since, called).stage)


func _restored() -> void:
	if Game.time_target() >= INBOUND_FROM and called < 0.0:
		_moored_already()


func _process(delta: float) -> void:
	_t += delta
	if Game.prologue or Game.dreaming:
		return
	if not _decided:
		_decided = true
		if Game.time_target() >= INBOUND_FROM:
			_moored_already()
	var hour := _hour()
	var before := since - called if called >= 0.0 else -INF
	if since < 0.0 and hour >= INBOUND_FROM:
		since = 0.0
	elif since >= 0.0:
		since += delta
	if since >= SAIL_IN and called < 0.0 and (hour >= BERTH_BY or _player_near()):
		called = since
	var p := pose(since, called)
	_apply(p, delta)
	if called >= 0.0:
		for e: String in events(before, since - called):
			_sound(e)
	if p.stage == Stage.MOORED and floori(_t / CREAK_EVERY) != floori((_t - delta) / CREAK_EVERY) \
			and floori(_t / CREAK_EVERY) % 2 == 0:
		_creak.pitch_scale = 0.9 + 0.2 * fposmod(_t * 0.37, 1.0)
		_creak.play()
		Game.caption("CAP_CREAK", _ship.global_position, 20.0)
	Game.harbour_ship = 0 if p.stage == Stage.HIDDEN else (2 if p.stage == Stage.MOORED else 1)


func _player_near() -> bool:
	var pl := get_tree().get_first_node_in_group(&"player") as Node3D
	return pl != null and pl.global_position.distance_to(berth()) < CALL_R


func _sound(e: String) -> void:
	match e:
		"hail":
			_audio.stream = preload("res://assets/audio/hail.wav")
			Game.caption("CAP_HAIL", _ship.global_position, 70.0)
		"line":
			_audio.stream = preload("res://assets/audio/line_thrown.wav")
			Game.caption("CAP_LINE", _ship.global_position, 30.0, 0)
		_:
			return
	_audio.play()


func _apply(p: Dictionary, _delta: float) -> void:
	_ship.visible = p.stage != Stage.HIDDEN
	var pos: Vector3 = p.pos
	var yaw := deg_to_rad(float(p.yaw))
	var k := float(p.roll)
	var f := Sea.float_pose(pos, yaw, 7.0, 2.2)
	# her keel runs along -x at the berth, so a surge ahead is towards the land
	var ahead := Vector3(cos(yaw), 0, -sin(yaw))
	_ship.position = Vector3(pos.x, WATERLINE + f.x, pos.z) + ahead * float(p.surge)
	_ship.rotation = Vector3(f.y * k, yaw, f.z * k)
	var furl := float(p.furl)
	if not is_equal_approx(furl, _furl):
		_furl = furl
		set_furl(_ship, furl)
	# the lines, re-laid on the 15 fps clock the harbour keeps
	var lines := float(p.lines)
	_lines.visible = lines > 0.0
	var step := floori(_t * 15.0)
	if _lines.visible and step != _line_step:
		_line_step = step
		_lay_lines(lines, float(p.taut))
	var g := float(p.gangway)
	_gangway.visible = g > 0.0
	if _gangway.visible:
		var e := gangway_ends()
		var down: Vector3 = ((e[0] as Vector3) - (e[1] as Vector3)).normalized()
		var dir := Vector3.UP.slerp(down, smoothstep(0.0, 1.0, g)).normalized()
		_gangway.global_transform = Transform3D(Basis.looking_at(dir, Vector3.FORWARD if absf(dir.y) > 0.99 else Vector3.UP), e[1])
	var working := at_work(_hour(), float(p.unload))
	# a storm sends the dockers under cover (once nobody is looking) and stops the hand at the rail
	var storm := Weather.storm_on(Weather.now(_hour()))
	for d: Npc in _dockers:
		Weather.duty(d, working, storm)
	_hand_jar.visible = working and not storm


func _lay_lines(thrown: float, taut: float) -> void:
	var kit := MeshKit.new()
	for e: Array in line_ends():
		var a: Vector3 = _ship.global_transform * (e[1] as Vector3)
		var pts := HARBOUR.mooring_line(a, e[0], lerpf(SLACK, HARBOUR.MOORING_SAG, taut))
		# thrown: the line runs out from her rail towards the bollard
		var reach := thrown * (pts.size() - 1)
		for i in pts.size() - 1:
			if i >= reach:
				break
			var p := pts[i]
			var q := pts[i + 1] if i + 1 <= reach else p.lerp(pts[i + 1], reach - i)
			if p.distance_to(q) < 0.01:
				continue
			kit.xform = Transform3D(Basis.looking_at(q - p, Vector3.UP), (p + q) / 2.0)
			kit.box("basket", Vector3.ZERO, Vector3(0.035, 0.035, p.distance_to(q) + 0.02), [])
	kit.xform = Transform3D.IDENTITY
	_lines.mesh = kit.commit()


func ship() -> Node3D:
	return _ship


func dockers() -> Array[Npc]:
	return _dockers


func stacked() -> int:
	return _stacked


func gangway() -> Node3D:
	return _gangway
