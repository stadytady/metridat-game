class_name GrainQuay
extends District
## Wheat for the ship at the pier. On the shingle north of the pier's root a
## heap of grain lies on a hide; Nikon the measurer fills the sacks from it
## (his measure and the levelling stick beside him, the full sacks stacked
## by), and two porters carry them one at a time onto the pier, along its
## north edge, to the pile waiting for the Swallow. The loan agreement she sails
## on lies on his crate under a stone (a find); his seal ring lies up the path
## from the town (an errand).
## The porters walk the ground (Topo.surface, so they step up onto the planks at
## the root where the shingle meets them) and have no body: the bot and the
## player walk the pier's middle beside them. By lamplight they are gone home.

const NPC := preload("res://scripts/npc/npc.gd")

const HEAP := Vector2(64.0, -9.6)
## The full sacks, stacked where the porters take them from.
const STACK := Vector2(64.9, -8.5)
const MEASURE := Vector2(63.6, -9.1)
const MEASURER := Vector2(63.0, -9.0)
const CRATE := Vector2(62.4, -9.6)
const CRATE_SIZE := Vector3(0.5, 0.4, 0.4)
## The pile on the pier by its north edge, waiting to go aboard: clear of the
## middle the walk along it keeps, and short of the anchor stock further out.
const PILE := Vector2(71.3, -6.95)
const PILE_SIZE := Vector3(1.4, 0.4, 0.5)
## Where the seal ring lies: on the slope beside the path down from the town.
const LOST_SEAL := Vector2(60.3, -4.4)
## A porter's round: [x, z, pose, pause s, facing yaw deg or NAN]. A sack off
## the stack, up onto the pier's root, along its north edge to the pile, and back.
const PORTER_ROUTE := [
	[64.3, -8.2, "pick", 2.4, -63.0],
	[63.3, -7.4, "walk", 0.0, NAN],
	[63.6, -6.85, "walk", 0.0, NAN],
	[70.2, -6.85, "pick", 1.4, -90.0],
	[63.6, -6.85, "walk", 0.0, NAN],
	[63.3, -7.4, "walk", 0.0, NAN],
]
const PORTER_TAKE := 0
const PORTER_DROP := 3
## The two porters: their looks, and where on the round each starts (the second
## at the pile, so they pass each other on the planks instead of walking in step).
const PORTERS := [
	[{"beard": 0, "hair": 2, "cloth": "chiton_dark"}, 0],
	[{"beard": 1, "hair": 0, "cloth": "chiton_ochre"}, 3],
]

var _porters: Array[Npc] = []
var _sacks: Array[Node3D] = []
var _atm: Node
var _home := true


func _ready() -> void:
	_atm = get_parent().get_node_or_null("Atmosphere")
	var kit := MeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5450
	_heap(kit, rng)
	_stack(kit, rng)
	_pile(kit, rng)
	# the measure and its levelling stick, and his crate
	var m := Vector3(MEASURE.x, ground(MEASURE), MEASURE.y)
	kit.lathe("wood", PackedVector2Array([Vector2(0.21, 0.0), Vector2(0.21, 0.34)]), 8, m, 1.0, true, "wood", true)
	kit.color = Color(1.0, 0.85, 0.55)
	kit.lathe("basket", PackedVector2Array([Vector2(0.19, 0.3), Vector2(0.15, 0.36), Vector2(0.0, 0.38)]), 8, m, 1.0, false)
	kit.color = Color.WHITE
	kit.box("wood", m + Vector3(0.0, 0.39, 0.0), Vector3(0.56, 0.03, 0.04), [])  # the stick across the rim
	var c := Vector3(CRATE.x, ground(CRATE), CRATE.y)
	kit.box("wood", c + Vector3(0, CRATE_SIZE.y / 2.0, 0), CRATE_SIZE, ["bottom"])
	add_child(kit.build("GrainQuay"))
	spawn_inspectable("loan_contract", c + Vector3(0, CRATE_SIZE.y, 0), 20.0)
	spawn_quest_item("seal", Vector3(LOST_SEAL.x, ground(LOST_SEAL) + 0.005, LOST_SEAL.y), 40.0)
	_measurer()
	for i in PORTERS.size():
		_porter(i)
	step(_hour())


static func ground(p: Vector2) -> float:
	return Topo.surface(p.x, p.y)


func _heap(kit: MeshKit, rng: RandomNumberGenerator) -> void:
	var h := Vector3(HEAP.x, ground(HEAP), HEAP.y)
	kit.box("fur", h + Vector3(0, 0.01, 0), Vector3(1.7, 0.02, 1.3), ["bottom"])
	kit.color = Color(1.0, 0.85, 0.55)
	kit.blob("basket", h + Vector3(0, 0.12, 0), Vector3(0.62, 0.22, 0.48), 0.25, rng)
	kit.blob("basket", h + Vector3(-0.2, 0.26, 0.05), Vector3(0.3, 0.14, 0.26), 0.25, rng)
	kit.color = Color.WHITE


func _stack(kit: MeshKit, rng: RandomNumberGenerator) -> void:
	var s := Vector3(STACK.x, ground(STACK), STACK.y)
	for o: Vector3 in [Vector3(-0.3, 0.2, 0.0), Vector3(0.28, 0.2, 0.05), Vector3(0.0, 0.2, -0.38), Vector3(0.0, 0.55, -0.15)]:
		kit.blob("sail", s + o, Vector3(0.3, 0.2, 0.24), 0.15, rng)


func _pile(kit: MeshKit, rng: RandomNumberGenerator) -> void:
	var y := Topo.PIER_H
	for i in 4:
		kit.blob("sail", Vector3(PILE.x - 0.5 + i * 0.34, y + 0.2, PILE.y), Vector3(0.24, 0.2, 0.22), 0.15, rng)
	kit.blob("sail", Vector3(PILE.x - 0.1, y + 0.52, PILE.y), Vector3(0.24, 0.18, 0.22), 0.15, rng)
	kit.add_collider(Vector3(PILE.x, y + PILE_SIZE.y / 2.0, PILE.y), PILE_SIZE)


func _measurer() -> void:
	var n: Npc = NPC.new()
	n.name = "Measurer"
	n.npc_id = "measurer"
	n.name_key = "NPC_MEASURER_NAME"
	n.dialogue = load("res://data/dialogues/measurer.dialogue") as DialogueResource
	n.pose = "stand"
	n.position = Vector3(MEASURER.x, ground(MEASURER), MEASURER.y)
	# a figure faces its local -z: turn from the heap towards him
	var d := MEASURER - HEAP
	n.rotation.y = atan2(d.x, d.y)
	add_child(n)


func _porter(i: int) -> void:
	var spec: Array = PORTERS[i]
	var start: int = spec[1]
	var n: Npc = NPC.new()
	n.name = "Porter%d" % i
	n.npc_id = "porter%d" % i
	n.name_key = "NPC_MEASURER_NAME"
	n.look = spec[0]
	n.pose = "stand"
	n.talkable = false
	n.solid = false
	n.follow_ground = true
	var r: Array = PORTER_ROUTE[start]
	n.position = Vector3(r[0], ground(Vector2(r[0], r[1])), r[1])
	set_porter_round(n, start)
	add_child(n)
	var sack := MeshInstance3D.new()
	var sk := MeshKit.new()
	sk.blob("sail", Vector3.ZERO, Vector3(0.24, 0.17, 0.2), 0.15, RandomNumberGenerator.new())
	sack.mesh = sk.commit()
	sack.position = Vector3(0, 0.05, -0.3)
	(n.joints["chest"] as Node3D).add_child(sack)
	# the second starts at the pile with his sack just put down
	sack.visible = start != PORTER_DROP
	n.carrying = sack.visible
	n.reached.connect(func(k: int) -> void:
		var at := posmod(k + start, PORTER_ROUTE.size())
		if at == PORTER_TAKE:
			sack.visible = true
			n.carrying = true
		elif at == PORTER_DROP:
			sack.visible = false
			n.carrying = false)
	_porters.append(n)
	_sacks.append(sack)


## A porter's round as a patrol, starting at `start` along PORTER_ROUTE. Static
## so the test can walk it.
static func set_porter_round(c: Npc, start := 0) -> void:
	var n := PORTER_ROUTE.size()
	var r0: Array = PORTER_ROUTE[start]
	var home := Vector3(r0[0], 0, r0[1])
	var pts := PackedVector3Array()
	var poses := PackedStringArray()
	var pauses := PackedFloat32Array()
	var faces := PackedFloat32Array()
	for k in n:
		var r: Array = PORTER_ROUTE[(start + k) % n]
		pts.append(Vector3(r[0], 0, r[1]) - home)
		poses.append(r[2])
		pauses.append(r[3])
		faces.append(r[4])
	c.patrol = pts
	c.patrol_poses = poses
	c.patrol_pauses = pauses
	c.patrol_faces = faces
	c.patrol_speed = 0.75
	c.stops_for_player = false
	c.carry_pose = "carry"


## The porters' points in the world, for tests.
static func porter_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for r: Array in PORTER_ROUTE:
		out.append(Vector2(r[0], r[1]))
	return out


## Whether the porters are at work at this hour: by lamplight they have gone home.
static func at_work(hour: float) -> bool:
	return hour < DayCycle.LAMPS_ON


func _hour() -> float:
	return float(_atm.t) if _atm != null else Game.time_target()


func _process(_delta: float) -> void:
	step(_hour())


func step(hour: float) -> void:
	var home := not at_work(hour)
	_home = home
	# home at lamplight at once; under cover from a storm once nobody is looking
	var storm := Weather.storm_on(Weather.now(hour))
	for p: Npc in _porters:
		Weather.duty(p, not home, storm)


func measurer() -> Npc:
	return get_node("Measurer")


func porters() -> Array[Npc]:
	return _porters
