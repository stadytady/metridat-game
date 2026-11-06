extends District
## A courtyard house south of the agora, the one house in the city you can
## walk into. A footpath leaves the square through a gap in the parapet and
## comes to the street door. Inside: an open courtyard where Myrto bakes
## flatbread in a clay oven, and two rooms under a lean-to roof on the south
## side: a living room round a hearth, with a couch and shelves, and a
## workroom with an upright loom, its warp held taut by clay loom weights.

const NPC := preload("res://scripts/npc/npc.gd")

const WALL_T := 0.4
const WALL_H := 2.6
## The rooms' front wall (onto the courtyard) and the back wall carry the roof.
const RANGE_Z := 22.0
const FRONT_H := 2.7
const BACK_H := 3.4
const DOOR_W := 1.5
const DOOR_H := 2.05
## Street door in the north wall, on the footpath.
const STREET_DOOR_X := 26.0
const ROOM_DOORS := [22.9, 29.1]
const DIVIDE_X := 26.2
const OVEN := Vector2(29.6, 18.6)
const HEARTH := Vector2(23.0, 24.7)
## Two finds: the loom weights on the workroom floor, the lamp on the living
## room's stool (its top is 0.44 m up).
const LOOM_WEIGHTS := Vector2(28.6, 24.4)
const LAMP_STOOL := Vector2(24.9, 23.3)
## Myrto's round: kneeling at the oven she bakes; when a bread is done she
## gets up with it and lays it on the stack on the board behind her, then
## kneels again. [x, z, pose, pause s, facing yaw deg].
const BAKER_ROUTE := [
	[28.65, 18.6, "baker", 14.0, -90.0],
	[28.15, 19.45, "pick", 2.0, -90.0],
]
## Where the board's stack of finished bread tops out, and how many she adds
## before the household takes them in.
const STACK_TOP := Vector3(29.17, 0.36, 19.45)
const STACK_MAX := 4

var _baker_npc: Npc
var _bread: Node3D
var _stack: Array[Node3D] = []
var _stacked := 0


static func bounds() -> Rect2:
	return Rect2(Topo.HOUSE_CENTER - Topo.HOUSE_HALF, Topo.HOUSE_HALF * 2.0)


## Wall pieces as [centre (floor level), size]: the outer walls with the
## street door, the rooms' front wall with two doorways, the wall between the
## rooms. Doorways are gaps; lintels are added separately.
static func walls() -> Array:
	var r := bounds()
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y
	var z1 := r.end.y
	var t := WALL_T
	var out := []
	var run := func(a: float, b: float, z: float, h: float, gaps: Array) -> void:
		var cur := a
		for g: float in gaps:
			out.append([Vector3((cur + g - DOOR_W / 2.0) / 2.0, 0, z), Vector3(g - DOOR_W / 2.0 - cur, h, t)])
			cur = g + DOOR_W / 2.0
		out.append([Vector3((cur + b) / 2.0, 0, z), Vector3(b - cur, h, t)])
	run.call(x0, x1, z0 + t / 2.0, WALL_H, [STREET_DOOR_X])
	run.call(x0, x1, z1 - t / 2.0, BACK_H, [])
	run.call(x0 + t, x1 - t, RANGE_Z, FRONT_H, ROOM_DOORS)
	for x: float in [x0 + t / 2.0, x1 - t / 2.0]:
		out.append([Vector3(x, 0, (z0 + RANGE_Z) / 2.0), Vector3(t, WALL_H, RANGE_Z - z0)])
		out.append([Vector3(x, 0, (RANGE_Z + z1) / 2.0), Vector3(t, FRONT_H, z1 - RANGE_Z)])
	out.append([Vector3(DIVIDE_X, 0, (RANGE_Z + z1) / 2.0), Vector3(t, FRONT_H, z1 - RANGE_Z - t)])
	return out


func _ready() -> void:
	var y := Topo.HOUSE_H
	var kit := MeshKit.new()
	Arch.platform(kit, Topo.HOUSE_CENTER, Topo.HOUSE_HALF, y, District.min_terrain(Topo.HOUSE_CENTER, Topo.HOUSE_HALF) - 1.0, "earth")
	Arch.path(kit, Topo.LANE, Topo.LANE_HALF, "earth")
	for w: Array in walls():
		var c: Vector3 = w[0]
		var size: Vector3 = w[1]
		kit.solid_box("plaster", Vector3(c.x, y + size.y / 2.0, c.z), size, ["bottom"])  # plastered mud brick
	_lintels(kit, y)
	# beaten clay floors in the rooms
	var r := bounds()
	for xs: Vector2 in [Vector2(r.position.x + WALL_T, DIVIDE_X - WALL_T / 2.0), Vector2(DIVIDE_X + WALL_T / 2.0, r.end.x - WALL_T)]:
		var f := y + 0.01
		kit.quad("mud", Vector3(xs.x, f, r.end.y - WALL_T), Vector3(xs.y, f, r.end.y - WALL_T), Vector3(xs.y, f, RANGE_Z + WALL_T / 2.0),
				Vector3(xs.x, f, RANGE_Z + WALL_T / 2.0))
	_roof(kit, y)
	_courtyard(kit, y)
	_living_room(kit, y)
	_workroom(kit, y)
	add_child(kit.build("House"))
	_oven_fire(y)
	_baker(y)
	# spare weights at the foot of the loom; the lamp on the stool by the hearth
	spawn_inspectable("loom_weights", Vector3(LOOM_WEIGHTS.x, y + 0.01, LOOM_WEIGHTS.y), 0.0)
	spawn_inspectable("oil_lamp", Vector3(LAMP_STOOL.x, y + 0.44, LAMP_STOOL.y), 120.0)
	place("pithos", Vector3(20.5, y, 17.2), 30.0, Vector3.ONE * 0.9, 0.45, 1.2)
	place("pithos", Vector3(21.4, y, 16.9), 110.0, Vector3.ONE * 0.75, 0.38, 1.0)
	place("amphora", Vector3(31.8, y, 17.0), 20.0, Vector3.ONE, 0.17, 0.8)
	place("amphora", Vector3(31.6, y, 21.2), 200.0, Vector3.ONE, 0.17, 0.8)
	place("pithos", Vector3(31.4, y, 25.9), 60.0, Vector3.ONE * 0.85, 0.42, 1.1)
	place("pithos", Vector3(31.5, y, 24.7), 150.0, Vector3.ONE * 0.7, 0.36, 0.95)


func _lintels(kit: MeshKit, y: float) -> void:
	var z0 := bounds().position.y + WALL_T / 2.0
	kit.box("wood", Vector3(STREET_DOOR_X, y + DOOR_H + 0.08, z0), Vector3(DOOR_W + 0.3, 0.16, WALL_T + 0.04), [])
	kit.solid_box("plaster", Vector3(STREET_DOOR_X, y + (DOOR_H + 0.16 + WALL_H) / 2.0, z0), Vector3(DOOR_W, WALL_H - DOOR_H - 0.16, WALL_T), [])
	for x: float in ROOM_DOORS:
		kit.box("wood", Vector3(x, y + DOOR_H + 0.08, RANGE_Z), Vector3(DOOR_W + 0.3, 0.16, WALL_T + 0.04), [])
		kit.solid_box("plaster", Vector3(x, y + (DOOR_H + 0.16 + FRONT_H) / 2.0, RANGE_Z), Vector3(DOOR_W, FRONT_H - DOOR_H - 0.16, WALL_T), [])


## A lean-to of tiles over the rooms, falling towards the courtyard; boarded underneath.
func _roof(kit: MeshKit, y: float) -> void:
	var r := bounds()
	var x0 := r.position.x - 0.2
	var x1 := r.end.x + 0.2
	var front := Vector3(0, y + FRONT_H - 0.05, RANGE_Z - 0.6)
	var back := Vector3(0, y + BACK_H + 0.1, r.end.y + 0.3)
	var a := Vector3(x0, front.y, front.z)
	var b := Vector3(x1, front.y, front.z)
	var c := Vector3(x1, back.y, back.z)
	var d := Vector3(x0, back.y, back.z)
	kit.quad("roof", a, b, c, d)
	var dn := Vector3(0, -0.06, 0)
	kit.quad("wood", a + dn, b + dn, c + dn, d + dn)  # boards under the tiles, seen from the rooms
	kit.quad("wood", b + dn, a + dn, d + dn, c + dn)
	# gable triangles between the side walls' tops and the roof slope, so the
	# rooms are closed to the sky; both windings, seen from both sides
	for x: float in [r.position.x + WALL_T / 2.0, r.end.x - WALL_T / 2.0, DIVIDE_X]:
		var p0 := Vector3(x, y + FRONT_H, RANGE_Z)
		var p1 := Vector3(x, y + FRONT_H, r.end.y)
		var p2 := Vector3(x, y + BACK_H, r.end.y)
		var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]
		kit.tri("plaster", p0, p1, p2, uv[0], uv[1], uv[2])
		kit.tri("plaster", p0, p2, p1, uv[0], uv[2], uv[1])


func _courtyard(kit: MeshKit, y: float) -> void:
	var o := Vector3(OVEN.x, y, OVEN.y)
	# tannur: a clay cylinder open at the top, the fire low inside it
	kit.lathe("clay", PackedVector2Array([Vector2(0.5, 0.0), Vector2(0.47, 0.3), Vector2(0.36, 0.7), Vector2(0.27, 0.78)]), 9, o, 2.0, false,
			"dark", true)
	kit.add_collider(o + Vector3(0, 0.4, 0), Vector3(0.9, 0.8, 0.9))
	# a stack of breads done, on a board, a basket, and the dough in its bowl
	var board := o + Vector3(-0.55, 0, 0.85)
	kit.solid_box("wood", board + Vector3(0, 0.12, 0), Vector3(0.7, 0.24, 0.45), ["bottom"])
	for i in 6:
		kit.lathe("bread", PackedVector2Array([Vector2(0.15, 0.0), Vector2(0.15, 0.018)]), 8,
				board + Vector3(0.12 + (i % 2) * 0.01, 0.24 + i * 0.02, 0.0), 1.0, false, "bread", true)
	kit.lathe("basket", PackedVector2Array([Vector2(0.12, 0.0), Vector2(0.17, 0.12)]), 7, board + Vector3(-0.2, 0.24, 0.02), 2.0, true, "dark", true)
	var bowl := o + Vector3(-1.25, 0, -0.65)
	kit.lathe("clay", PackedVector2Array([Vector2(0.12, 0.0), Vector2(0.24, 0.14), Vector2(0.25, 0.16)]), 8, bowl, 1.0, true, "clay", false)
	kit.blob("dough", bowl + Vector3(0, 0.15, 0), Vector3(0.18, 0.08, 0.16), 0.2, RandomNumberGenerator.new())
	# saddle quern for the barley, and brushwood for the oven
	var q := Vector3(21.6, y, 18.6)
	kit.solid_box("rock", q + Vector3(0, 0.12, 0), Vector3(0.9, 0.24, 0.45), ["bottom"])
	kit.box("rock", q + Vector3(0.1, 0.29, 0), Vector3(0.3, 0.1, 0.38), ["bottom"])
	for i in 7:
		kit.xform = Transform3D(Basis(Vector3.UP, 0.15 * i - 0.4) * Basis(Vector3.FORWARD, PI / 2.0 - 0.15), Vector3(31.75, y + 0.05 + i * 0.01, 19.2 + i * 0.12))
		kit.lathe("bark", PackedVector2Array([Vector2(0.03, -0.5), Vector2(0.025, 0.5)]), 4, Vector3.ZERO, 1.0, false)
	kit.xform = Transform3D.IDENTITY


## The living room: a round hearth in the middle, a couch with a fleece along the
## west wall, a shelf of pots on the back wall, a stool and a lamp stand.
func _living_room(kit: MeshKit, y: float) -> void:
	var h := Vector3(HEARTH.x, y, HEARTH.y)
	for i in 9:
		var a := TAU * i / 9.0
		kit.box("rock", h + Vector3(cos(a) * 0.5, 0.06, sin(a) * 0.5), Vector3(0.22, 0.12, 0.2), ["bottom"])
	kit.quad("dark", h + Vector3(-0.42, 0.01, 0.42), h + Vector3(0.42, 0.01, 0.42), h + Vector3(0.42, 0.01, -0.42), h + Vector3(-0.42, 0.01, -0.42))
	for i in 3:
		kit.xform = Transform3D(Basis(Vector3.UP, i * 1.1) * Basis(Vector3.FORWARD, PI / 2.0), h + Vector3(0, 0.06, 0))
		kit.lathe("bark", PackedVector2Array([Vector2(0.04, -0.3), Vector2(0.04, 0.3)]), 4, Vector3.ZERO, 1.0, false)
	kit.xform = Transform3D.IDENTITY
	# couch (kline) with a fleece
	var x0 := bounds().position.x + WALL_T
	kit.solid_box("wood", Vector3(x0 + 0.5, y + 0.22, 24.4), Vector3(0.9, 0.44, 2.2), ["bottom"])
	kit.box("fleece", Vector3(x0 + 0.5, y + 0.47, 24.4), Vector3(0.85, 0.06, 2.0), ["bottom"])
	kit.box("cloth", Vector3(x0 + 0.5, y + 0.55, 23.5), Vector3(0.6, 0.12, 0.35), ["bottom"])  # bolster
	# shelf of pots on the back wall
	var zb := bounds().end.y - WALL_T
	kit.solid_box("wood", Vector3(23.8, y + 1.3, zb - 0.18), Vector3(2.2, 0.06, 0.36), [])
	for i in 4:
		kit.lathe("clay" if i % 2 else "redfigure", PackedVector2Array([Vector2(0.06, 0.0), Vector2(0.1, 0.1), Vector2(0.06, 0.2), Vector2(0.07, 0.24)]), 7,
				Vector3(22.9 + i * 0.55, y + 1.33, zb - 0.18), 1.0, true, "dark", false)
	kit.solid_box("wood", Vector3(24.9, y + 0.22, 23.3), Vector3(0.4, 0.44, 0.4), ["bottom"])  # stool


## The workroom: an upright loom against the back wall, cloth woven at the top,
## the warp hanging below it in groups weighted by clay loom weights; a wool
## basket and a lamp stand.
func _workroom(kit: MeshKit, y: float) -> void:
	var zb := bounds().end.y - WALL_T - 0.45
	var xa := 27.8
	var xb := 30.6
	for x: float in [xa, xb]:
		kit.solid_box("wood", Vector3(x, y + 1.05, zb), Vector3(0.1, 2.1, 0.1), ["bottom"])
	kit.box("wood", Vector3((xa + xb) / 2.0, y + 2.0, zb), Vector3(xb - xa + 0.3, 0.1, 0.1), [])
	kit.box("wood", Vector3((xa + xb) / 2.0, y + 1.0, zb + 0.02), Vector3(xb - xa, 0.05, 0.05), [])  # shed bar
	# leaning back against the wall, as these looms stood
	var lean := Basis(Vector3.RIGHT, -0.12)
	var c := Vector3((xa + xb) / 2.0, y, zb)
	kit.xform = Transform3D(lean, c)
	var hw := (xb - xa) / 2.0 - 0.1
	kit.quad("chiton", Vector3(-hw, 1.3, -0.02), Vector3(hw, 1.3, -0.02), Vector3(hw, 1.95, -0.02), Vector3(-hw, 1.95, -0.02))
	kit.quad("chiton", Vector3(hw, 1.3, -0.01), Vector3(-hw, 1.3, -0.01), Vector3(-hw, 1.95, -0.01), Vector3(hw, 1.95, -0.01))
	var groups := 9
	for i in groups:
		var gx := -hw + 0.1 + i * (hw * 2.0 - 0.2) / (groups - 1)
		kit.box("cloth", Vector3(gx, 0.88, -0.02), Vector3(0.04, 0.84, 0.01), [])  # a group of warp threads
		kit.box("clay", Vector3(gx, 0.42, -0.03), Vector3(0.1, 0.12, 0.06), [])  # its loom weight
	kit.xform = Transform3D.IDENTITY
	kit.lathe("basket", PackedVector2Array([Vector2(0.15, 0.0), Vector2(0.22, 0.25)]), 7, Vector3(27.3, y, 24.0), 2.0, true, "dark", true)
	kit.blob("fleece", Vector3(27.3, y + 0.28, 24.0), Vector3(0.18, 0.1, 0.18), 0.25, RandomNumberGenerator.new())
	kit.solid_box("wood", Vector3(29.2, y + 0.22, 24.6), Vector3(0.4, 0.44, 0.4), ["bottom"])  # the weaver's stool


## Fire in the oven and on the hearth, and a lamp in the workroom: the rooms
## under the roof are dark without them, day or night.
func _oven_fire(y: float) -> void:
	var lights := [
		[Vector3(OVEN.x, y + 0.5, OVEN.y), Color(1, 0.55, 0.25), 3.0, 0.9],
		[Vector3(HEARTH.x, y + 0.5, HEARTH.y), Color(1, 0.6, 0.3), 5.5, 1.6],
		[Vector3(29.2, y + 1.6, 24.2), Color(1, 0.7, 0.4), 4.5, 1.2],
	]
	for l: Array in lights:
		var o := OmniLight3D.new()
		o.position = l[0]
		o.light_color = l[1]
		o.omni_range = l[2]
		o.set_script(preload("res://scripts/world/flicker.gd"))
		o.base_energy = l[3]
		o.amount = 0.25
		add_child(o)
	var fk := MeshKit.new()
	fk.box("flame", Vector3(HEARTH.x, y + 0.2, HEARTH.y), Vector3(0.22, 0.3, 0.22), [])
	fk.box("flame", Vector3(HEARTH.x + 0.12, y + 0.14, HEARTH.y - 0.08), Vector3(0.12, 0.18, 0.12), [])
	fk.lathe("flame", PackedVector2Array([Vector2(0.22, 0.79), Vector2(0.22, 0.8)]), 9, Vector3(OVEN.x, y, OVEN.y), 1.0, false, "flame", true)  # embers in the mouth
	# lamp stand by the loom
	var ls := Vector3(29.2, y, 24.2)
	fk.box("bronze", ls + Vector3(0, 0.65, 0), Vector3(0.05, 1.3, 0.05), ["bottom"])
	fk.lathe("clay", PackedVector2Array([Vector2(0.05, 0.0), Vector2(0.08, 0.03), Vector2(0.06, 0.07)]), 6, ls + Vector3(0, 1.3, 0), 1.0, true, "dark", true)
	fk.box("flame", ls + Vector3(0.1, 1.42, 0), Vector3(0.04, 0.07, 0.04), [])
	add_child(fk.build("Fires"))


## Myrto's round as a patrol. Static so the test can walk it.
static func set_baker_round(b: Npc) -> void:
	var home := Vector3(BAKER_ROUTE[0][0], 0, BAKER_ROUTE[0][1])
	var pts := PackedVector3Array()
	var poses := PackedStringArray()
	var pauses := PackedFloat32Array()
	var faces := PackedFloat32Array()
	for r: Array in BAKER_ROUTE:
		pts.append(Vector3(r[0], 0, r[1]) - home)
		poses.append(r[2])
		pauses.append(r[3])
		faces.append(r[4])
	b.patrol = pts
	b.patrol_poses = poses
	b.patrol_pauses = pauses
	b.patrol_faces = faces
	b.patrol_speed = 0.45
	# she keeps baking while she is watched; a talk holds the world anyway
	b.stops_for_player = false


static func _loaf() -> MeshInstance3D:
	var k := MeshKit.new()
	k.lathe("bread", PackedVector2Array([Vector2(0.15, 0.0), Vector2(0.15, 0.018)]), 8, Vector3.ZERO, 1.0, false, "bread", true)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	return mi


## Myrto, kneeling at the oven. A woman's figure: hair long down the back
## under a kerchief, and a long chiton over the knees.
func _baker(y: float) -> void:
	var b: Npc = NPC.new()
	b.npc_id = "baker"
	b.name_key = "NPC_BAKER_NAME"
	b.dialogue = load("res://data/dialogues/baker.dialogue") as DialogueResource
	b.pose = "baker"
	b.body_mat = "chiton_dark"
	b.position = Vector3(OVEN.x - 0.95, y, OVEN.y)
	b.rotation.y = deg_to_rad(-90.0)  # faces +x, the oven
	set_baker_round(b)
	add_child(b)
	_baker_npc = b
	# the bread she carries, flat against her chest, and the ones she adds to the stack
	_bread = _loaf()
	_bread.position = Vector3(0, 0.3, -0.38)  # on the palms, the forearms raised under it
	_bread.visible = false
	(b.joints["chest"] as Node3D).add_child(_bread)
	for i in STACK_MAX:
		var l := _loaf()
		l.position = STACK_TOP + Vector3(0.01 * (i % 2), y + 0.02 * i, 0)
		l.visible = false
		add_child(l)
		_stack.append(l)
	b.departed.connect(func(i: int) -> void:
		if i == 0:
			_bread.visible = true
			_baker_npc.carrying = true)
	b.reached.connect(func(i: int) -> void:
		if i == 1:
			_bread.visible = false
			_baker_npc.carrying = false
			# the household takes a full stack in, and she starts another
			if _stacked == STACK_MAX:
				_stacked = 0
				for l: Node3D in _stack:
					l.visible = false
			_stack[_stacked].visible = true
			_stacked += 1)
	# kerchief, hair and the long chiton to the ground: Figure.LOOKS["baker"]
