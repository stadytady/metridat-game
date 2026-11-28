class_name TownDay
extends District
## The town's day and night, beyond the work every NPC does at his own spot:
##  - the agora fills in the morning, thins out at midday when two old men sit
##    on the stoa step out of the sun, and fills a little again towards evening
##    (market_folk(hour), shade_sitters(hour));
##  - after dark a supper party in a house on the Street of Jars: light at the
##    door, voices and a pipe behind the wall, and now and then a guest going
##    unsteadily down the street with his lamp and back;
##  - pack donkeys with their drivers up and down the Street of Jars by day;
##  - out on the strait two fishing boats crossing, and dolphins.
## Nothing here has a collider or a line: weather, not furniture, so none of it
## stands in the walked route. Every hour comes from DayCycle via the
## Atmosphere, and the night from DayCycle.LAMPS_ON, as everywhere else.

const NPC := preload("res://scripts/npc/npc.gd")
const SYMPOSIUM_SOUND := preload("res://assets/audio/symposium.wav")

## Morning ends, midday ends: the square's own hours (DayCycle 0 dawn .. 1 night).
const MORNING_END := 0.36
const MIDDAY_END := 0.55
## Extra people crossing the square: [from, to, speed, look].
const MARKET_FOLK := [
	[Vector2(12.5, -1.5), Vector2(24.0, -2.6), 0.5, {"beard": 1, "hair": 0, "cloth": "chiton_ochre"}],
	[Vector2(27.5, 5.2), Vector2(16.5, 4.6), 0.42, {"woman": true, "kerchief": "cloth", "skirt": "long", "cloth": "chiton_blue"}],
	[Vector2(22.0, 9.6), Vector2(13.0, 9.0), 0.6, {"beard": 0, "hair": 1, "cloth": "chiton"}],
	[Vector2(29.0, -6.4), Vector2(29.0, 1.8), 0.46, {"woman": true, "kerchief": "chiton_dark", "skirt": "long", "cloth": "chiton_red"}],
]
## Where the people crossing the square stand out of the rain: inside the stoa,
## on its floor (a step up), between the columns and the back wall, looking out.
const SHELTER_SPOTS := [Vector2(15.5, -7.4), Vector2(19.3, -8.1), Vector2(24.6, -7.3), Vector2(28.2, -7.9)]
const STOA_FLOOR := 0.32
## Two old men on the stoa step, between its columns, facing the square.
const SHADE_SEATS := [Vector2(17.6, -4.86), Vector2(18.7, -4.86)]

## The supper party: a house on the north side of the Street of Jars at this x.
const SYMPOSIUM_X := -38.0
## How far down the street (and back) the guest wanders with his lamp.
const GUEST_WANDER := 7.0
## The pack donkeys walk this stretch of the street (x from, to), each its own
## part of it.
const DONKEY_STRETCH := [Vector2(-56.0, -40.0), Vector2(-30.0, -10.0)]
## Fishing boats crossing the strait: [from, to] far out, slow.
const BOATS := [[Vector2(112.0, -70.0), Vector2(120.0, 40.0)], [Vector2(146.0, 34.0), Vector2(138.0, -58.0)]]
const BOAT_SPEED := 0.9
## The dolphins: a pod circling here, each surfacing on its own beat.
const POD := Vector2(98.0, 24.0)
const POD_R := 9.0
const DOLPHINS := 3
const DOLPHIN_BEAT := 2.8  # s from one leap to the next
const DOLPHIN_LEAP := 0.95  # s out of the water

var _atm: Node
var _walkers: Array[Npc] = []
var _sitters: Array[Npc] = []
## The same people, standing in the stoa while it rains.
var _sheltering: Array[Npc] = []
var _party_light: OmniLight3D
var _party_door: MeshInstance3D
var _party_sound: AudioStreamPlayer3D
var _guest: Npc
var _boats: Array[Node3D] = []
var _boat_dist: Array[float] = []
var _dolphins: Array[Node3D] = []
var _t := 0.0
var night := false


func _ready() -> void:
	_atm = get_parent().get_node_or_null("Atmosphere")
	_market()
	_symposium()
	_donkeys()
	_strait()
	step(0.0)


## How many of the extra people cross the square at this hour.
static func market_folk(hour: float) -> int:
	if hour >= DayCycle.LAMPS_ON:
		return 0
	if hour < MORNING_END:
		return MARKET_FOLK.size()
	if hour < MIDDAY_END:
		return 1
	return MARKET_FOLK.size() - 1


## Whether the old men sit on the stoa step: in the heat of the day and on
## into the evening, not in the busy morning and not at night.
static func shade_sitters(hour: float) -> bool:
	return hour >= MORNING_END and hour < DayCycle.LAMPS_ON


## Whether the supper party is on (the town's own dusk).
static func party_at(hour: float) -> bool:
	return hour >= DayCycle.LAMPS_ON and hour < DayCycle.DREAM


func _market() -> void:
	var y := Topo.AGORA_H
	for i in MARKET_FOLK.size():
		var f: Array = MARKET_FOLK[i]
		var a: Vector2 = f[0]
		var b: Vector2 = f[1]
		var n: Npc = NPC.new()
		n.name = "Market%d" % i
		n.talkable = false
		n.solid = false
		n.stops_for_player = false
		n.look = f[3]
		n.pose = "stand"
		n.position = Vector3(a.x, y, a.y)
		n.patrol = PackedVector3Array([Vector3(b.x - a.x, 0, b.y - a.y), Vector3.ZERO])
		n.patrol_speed = f[2]
		n.patrol_pause = 1.2
		n.patrol_poses = PackedStringArray(["stand", "stand"])
		add_child(n)
		_walkers.append(n)
		var s: Vector2 = SHELTER_SPOTS[i]
		var c: Npc = NPC.new()
		c.name = "Sheltering%d" % i
		c.talkable = false
		c.solid = false
		c.look = f[3]
		c.pose = "stand"
		c.position = Vector3(s.x, y + STOA_FLOOR, s.y)
		c.rotation.y = PI + (0.4 if i % 2 == 0 else -0.4)  # out at the rain, a little to each other
		c.visible = false
		add_child(c)
		_sheltering.append(c)
	for i in SHADE_SEATS.size():
		var s: Vector2 = SHADE_SEATS[i]
		var n: Npc = NPC.new()
		n.name = "Elder%d" % i
		n.talkable = false
		n.solid = false
		n.stops_for_player = false
		n.look = {"beard": 2, "hair": 2, "cloth": "chiton" if i == 0 else "chiton_dark"}
		# on the step's edge (0.32 high, the "sit_think" seat), feet on the paving
		n.pose = "sit_think"
		n.position = Vector3(s.x, y, s.y)
		# out over the square (+z), turned a little to each other: two men talking,
		# and their thighs read as sitting, not as two short men standing
		n.rotation.y = PI - 0.35 if i == 0 else PI + 0.35
		add_child(n)
		_sitters.append(n)


## The house front on the north side of the street at x, as street.gd places it:
## [front point on the wall, the way out of the house towards the street].
static func house_front(x: float) -> Array:
	var dz := Topo.street_z(x + 0.5) - Topo.street_z(x - 0.5)
	var dir := Vector3(1, 0, dz).normalized()
	var out := Vector3(-dir.z, 0, dir.x)  # side +1: away from the street
	var front := Vector3(x, Topo.street_height(x), Topo.street_z(x)) + out * (Topo.STREET_HALF + 0.2)
	return [front, -out]


func _symposium() -> void:
	var hf: Array = house_front(SYMPOSIUM_X)
	var front: Vector3 = hf[0]
	var toward: Vector3 = hf[1]
	# the door left ajar: a lit gap on the wall, just proud of it
	var kit := MeshKit.new()
	var c := front + toward * 0.03 + Vector3(0, 0.95, 0)
	var side := Vector3.UP.cross(toward).normalized() * 0.42
	kit.quad("window_glow", c - side - Vector3(0, 0.9, 0), c + side - Vector3(0, 0.9, 0), c + side + Vector3(0, 0.9, 0), c - side + Vector3(0, 0.9, 0))
	_party_door = MeshInstance3D.new()
	_party_door.mesh = kit.commit()
	add_child(_party_door)
	_party_light = OmniLight3D.new()
	_party_light.position = front + toward * 0.8 + Vector3(0, 1.6, 0)
	_party_light.light_color = Color(1.0, 0.66, 0.34)
	_party_light.omni_range = 7.0
	_party_light.shadow_enabled = false
	_party_light.set_script(preload("res://scripts/world/flicker.gd"))
	_party_light.base_energy = 1.4
	_party_light.amount = 0.35
	add_child(_party_light)
	_party_sound = AudioStreamPlayer3D.new()
	_party_sound.stream = SYMPOSIUM_SOUND
	_party_sound.position = front + Vector3(0, 1.4, 0)
	_party_sound.unit_size = 4.0
	_party_sound.max_distance = 30.0
	_party_sound.volume_db = -6.0
	_party_sound.bus = &"Master"
	add_child(_party_sound)
	# a guest going home, or pretending to: down the street with his lamp, and back
	var g: Npc = NPC.new()
	g.name = "Guest"
	g.talkable = false
	g.solid = false
	g.stops_for_player = false
	g.follow_ground = true
	g.look = {"beard": 1, "hair": 1, "cloth": "chiton_red"}
	var start := front + toward * 1.2
	g.position = Vector3(start.x, Topo.surface(start.x, start.z), start.z)
	var end_x := SYMPOSIUM_X + GUEST_WANDER
	var end := Vector3(end_x, 0, Topo.street_z(end_x) + 0.6)
	g.patrol = PackedVector3Array([Vector3.ZERO, Vector3(end.x - start.x, 0, end.z - start.z)])
	g.patrol_speed = 0.45
	g.patrol_poses = PackedStringArray(["stand", "stand"])
	g.patrol_pauses = PackedFloat32Array([6.0, 3.0])
	add_child(g)
	var lamp := Lamp._make_flame(0.12)
	lamp.position = Vector3(0, -0.36, 0)
	(g.joints["r_elbow"] as Node3D).add_child(lamp)
	_guest = g


func _donkeys() -> void:
	for i in DONKEY_STRETCH.size():
		var s: Vector2 = DONKEY_STRETCH[i]
		var d := Rider.new()
		d.name = "Donkey%d" % i
		d.body = {"ears": 0.26, "mane": 0.05}
		d.panniers = true
		d.on_paving = true
		d.walker_look = {"beard": 2 - i, "hair": i, "cloth": "chiton_dark" if i == 0 else "chiton_ochre"}
		d.speed = 0.75
		d.route = street_stretch(s.x, s.y)
		d.travelled = float(i) * 5.0
		d.scale = Vector3.ONE * 0.82  # a donkey, smaller than the mule in the pen
		add_child(d)


## Points along the middle of the street from x0 to x1, a metre apart, off the
## centre line to the south a little so the donkey keeps to one side.
static func street_stretch(x0: float, x1: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var x := x0
	while x <= x1 + 0.01:
		var z := Topo.street_z(x) + 0.7
		out.append(Vector3(x, Topo.surface(x, z), z))
		x += 1.0
	return out


func _strait() -> void:
	for i in BOATS.size():
		var b := Node3D.new()
		b.name = "Boat%d" % i
		var kit := MeshKit.new()
		Props.boat(kit)
		# the fisherman at the oars: a figure would be a dot this far out, a hump is enough
		kit.box("chiton_dark", Vector3(0.0, 0.55, 0.0), Vector3(0.3, 0.5, 0.3), [])
		b.add_child(kit.build("Hull"))
		add_child(b)
		_boats.append(b)
		_boat_dist.append(float(i) * 40.0)
	for i in DOLPHINS:
		var d := Node3D.new()
		d.name = "Dolphin%d" % i
		var kit := MeshKit.new()
		kit.box("lead", Vector3(0, 0, 0), Vector3(0.36, 0.34, 1.6), [])  # body
		kit.box("lead", Vector3(0, 0.0, -0.95), Vector3(0.18, 0.16, 0.4), [])  # beak, forward
		kit.box("lead", Vector3(0, 0.27, 0.1), Vector3(0.06, 0.28, 0.3), [])  # fin
		kit.box("lead", Vector3(0, 0.0, 0.9), Vector3(0.7, 0.06, 0.22), [])  # flukes
		d.add_child(kit.build("Body"))
		add_child(d)
		_dolphins.append(d)


## Where a dolphin is at time t: [position, heading angle, out of the water].
## It swims round the pod's circle; every DOLPHIN_BEAT it leaps for DOLPHIN_LEAP
## seconds in an arc, nose up then nose down; the rest of the time it is under.
static func dolphin_at(i: int, t: float) -> Array:
	var ang := t * 0.11 + float(i) * TAU / float(DOLPHINS)
	var p := POD + Vector2(cos(ang), sin(ang)) * (POD_R + float(i) * 1.3)
	var beat := fposmod(t + float(i) * 0.9, DOLPHIN_BEAT)
	var out := beat < DOLPHIN_LEAP
	var u := beat / DOLPHIN_LEAP
	var y := sin(u * PI) * 0.9 - 0.25 if out else -1.5
	var pitch := lerpf(0.6, -0.6, u) if out else 0.0
	# facing along the circle (counter-clockwise): a figure-like -z forward
	return [Vector3(p.x, y, p.y), atan2(sin(ang), -cos(ang)), out, pitch]


func _process(delta: float) -> void:
	step(delta)


## One person on the square or in the stoa: the hour decides at once whether
## they are out at all; the rain moves them in and out only while neither
## place is in the player's view.
static func _shelter(walker: Npc, twin: Npc, out: bool, cover: bool) -> void:
	var covered := bool(walker.get_meta(&"cover", false))
	if not out:
		covered = false
	elif cover != covered and Weather.unseen(walker) and Weather.unseen(twin):
		covered = cover
	walker.set_meta(&"cover", covered)
	var walking := out and not covered
	if walker.visible != walking:
		walker.visible = walking
		walker.process_mode = Node.PROCESS_MODE_INHERIT if walking else Node.PROCESS_MODE_DISABLED
	twin.visible = out and covered


func walkers() -> Array[Npc]:
	return _walkers


func sheltering() -> Array[Npc]:
	return _sheltering


func step(delta: float) -> void:
	_t += delta
	var hour := float(_atm.t) if _atm != null else Game.time_target()
	var n := market_folk(hour)
	# in the rain they go into the stoa: the one crossing the square is the one
	# standing in it, and the swap waits until the player looks away (Weather.duty)
	var cover := Weather.sheltering(Weather.now(hour))
	for i in _walkers.size():
		_shelter(_walkers[i], _sheltering[i], i < n, cover)
	var sit := shade_sitters(hour)
	for s in _sitters:
		s.visible = sit
	var party := party_at(hour)
	if party != night or delta == 0.0:
		night = party
		_party_light.visible = party
		_party_door.visible = party
		_guest.visible = party
		if party and _party_sound.is_inside_tree() and not _party_sound.playing:
			_party_sound.play()
		elif not party:
			_party_sound.stop()
	if party:
		Game.caption("CAP_SYMPOSIUM", _party_sound.global_position, 14.0)
	# the donkeys go home with the light, like the day workers
	for d in get_children():
		if d is Rider:
			d.visible = hour < DayCycle.LAMPS_ON
	var q := floorf(_t * 15.0) / 15.0
	for i in _boats.size():
		_boat_dist[i] += BOAT_SPEED * delta
		var line: Array = BOATS[i]
		var a: Vector2 = line[0]
		var b: Vector2 = line[1]
		var pts: Array[Vector3] = [Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y)]
		var at: Array = Rider.along(pts, _boat_dist[i])
		var p: Vector2 = at[0]
		var h: Vector2 = at[1]
		# the boat model's bow is +x: its heading angle about y
		var yaw := atan2(-h.y, h.x)
		var f := Sea.float_pose(Vector3(p.x, 0, p.y), yaw, 2.2, 0.5, q)
		_boats[i].position = Vector3(p.x, f.x - 0.18, p.y)
		_boats[i].rotation = Vector3(f.y, yaw, f.z)
	for i in _dolphins.size():
		var s: Array = dolphin_at(i, q)
		var pos: Vector3 = s[0]
		_dolphins[i].visible = s[2]
		_dolphins[i].position = Vector3(pos.x, Sea.height_at(pos.x, pos.z, q) + pos.y, pos.z)
		_dolphins[i].rotation = Vector3(s[3], s[1], 0)


func guest() -> Npc:
	return _guest
