extends District
## Fisherman's camp on the beach below the agora: a small boat hauled up the
## shingle, a net drying on two poles, baskets of the morning catch, a stone
## to sit on and a driftwood fire. Glaukos sits on his stone gutting the catch
## on a board, a fish at a time for about seventy seconds (FISHER_ROUTE), then
## gets up, takes another from the baskets by the boat and sits down again.

const NPC := preload("res://scripts/npc/npc.gd")

const SEAT := Vector2(65.6, 14.6)
const BOAT := Vector2(69.6, 16.4)
const RACK := [Vector2(63.6, 11.0), Vector2(66.6, 11.0)]
const FIRE := Vector2(64.4, 17.0)
const SINKERS := Vector2(65.7, 13.6)
## The morning catch in two baskets by the boat.
const CATCH := [Vector2(67.4, 13.2), Vector2(67.9, 14.0)]
## The gutting board on a flat stone before his knees, the knife side to his
## right; the gutted fish go into a flat basket at his left.
const BOARD := Vector2(64.98, 14.6)
const BOARD_TOP := 0.3
const GUTTED := Vector2(65.55, 15.35)
const GUTTED_MAX := 5
## His round: [x, z, pose, pause s, facing yaw deg]. Seventy seconds at the
## board facing west up the beach, then a few steps to the first catch basket,
## bent over it a moment (facing it), and back.
const FISHER_ROUTE := [
	[65.6, 14.6, "gut", 70.0, 90.0],
	[66.85, 13.75, "pick", 2.5, -45.0],
]
const FISHER_BOARD := 0
const FISHER_CATCH := 1
## Cormorants on the beach some fifty metres south of the Swallow, above the
## surf: a patch of sand they walk, and two rocks they dry their wings on.
## Glaukos's errand: a hook dropped behind his boat, on the sea side of the
## hull, where nobody standing at the camp can see it.
const LOST_HOOK := Vector2(70.0, 17.36)
const CORMORANT_SAND := Vector2(65.0, 40.2)
const CORMORANT_SAND_R := 2.2
const CORMORANT_ROCKS := [Vector3(66.9, 0.0, 38.9), Vector3(67.4, 0.0, 41.6)]
const CORMORANTS_ON_SAND := 3
## The beach's own boulders keep this far off the colony (built into a scratch
## kit, as on the camp, so the rng and every other rock stay where they were).
const CORMORANT_CLEAR := 6.0


static func ground(p: Vector2) -> float:
	return Topo.terrain(p.x, p.y)


## Corner of a quad lying on the slope, lifted a little so it does not z-fight.
static func on_ground(x: float, z: float, lift: float = 0.03) -> Vector3:
	return Vector3(x, Topo.terrain(x, z) + lift, z)


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 57
	var kit := MeshKit.new()
	_rack(kit)
	_seat_and_nets(kit, rng)
	_baskets(kit, rng)
	_fire_ring(kit, rng)
	_cormorant_rocks(kit, rng)
	add_child(kit.build("Camp", &"dirt"))
	_cormorants()
	spawn_quest_item("hook", Vector3(LOST_HOOK.x, ground(LOST_HOOK) + 0.01, LOST_HOOK.y), 60.0)
	_boat()
	_fire()
	_fisherman()
	spawn_inspectable("net_sinkers", Vector3(SINKERS.x, ground(SINKERS) + 0.36, SINKERS.y), 20.0)


## The drying rack: two poles and a bar, and a net thrown over the bar. It
## hangs down both sides a metre or so, its foot sagging between the poles and
## splayed a little, so it reads as cloth over a pole and not as a fence.
func _rack(kit: MeshKit) -> void:
	var top := 1.85
	var a: Vector2 = RACK[0]
	var b: Vector2 = RACK[1]
	var bar_y := rack_bar_y()
	for p: Vector2 in RACK:
		# every pole up to the bar, whatever the shingle does under it
		var g := ground(p)
		var h := bar_y + 0.12 - g
		kit.solid_box("wood", Vector3(p.x, g + h / 2.0, p.y), Vector3(0.1, h, 0.1), ["bottom"])
	kit.box("wood", Vector3((a.x + b.x) / 2.0, bar_y, a.y), Vector3(b.x - a.x + 0.3, 0.07, 0.07), [])
	var n := NET_COLUMNS
	for side: float in [-1.0, 1.0]:
		for i in n:
			var u0 := float(i) / n
			var u1 := float(i + 1) / n
			var x0 := lerpf(a.x + 0.08, b.x - 0.08, u0)
			var x1 := lerpf(a.x + 0.08, b.x - 0.08, u1)
			var t0 := Vector3(x0, bar_y, a.y + side * 0.03)
			var t1 := Vector3(x1, bar_y, a.y + side * 0.03)
			var f0 := Vector3(x0, bar_y - net_drop(u0), a.y + side * NET_SPLAY)
			var f1 := Vector3(x1, bar_y - net_drop(u1), a.y + side * NET_SPLAY)
			# the outer face of each side, wound outwards (cutout, seen from both)
			if side > 0.0:
				kit.quad("net", f0, f1, t1, t0)
			else:
				kit.quad("net", f1, f0, t0, t1)
	kit.add_collider(Vector3((a.x + b.x) / 2.0, bar_y - NET_HANG / 2.0, a.y), Vector3(b.x - a.x, NET_HANG, 0.1 + NET_SPLAY * 2.0))


const NET_COLUMNS := 8
## How far the net hangs below the bar at the poles, and how much more it sags
## in the middle; how far its foot stands out from the bar on each side.
const NET_HANG := 0.95
const NET_SAG := 0.3
const NET_SPLAY := 0.12


## The bar's height: the poles stand on different shingle, the bar is level.
static func rack_bar_y() -> float:
	return maxf(ground(RACK[0]), ground(RACK[1])) + 1.77


## How far below the bar the net's foot hangs, u along the bar (0..1).
static func net_drop(u: float) -> float:
	return NET_HANG + NET_SAG * 4.0 * u * (1.0 - u)


func _seat_and_nets(kit: MeshKit, rng: RandomNumberGenerator) -> void:
	var g := ground(SEAT)
	kit.blob("rock", Vector3(SEAT.x + 0.05, g + 0.16, SEAT.y), Vector3(0.32, 0.26, 0.3), 0.15, rng)
	kit.add_collider(Vector3(SEAT.x, g + 0.2, SEAT.y), Vector3(0.6, 0.4, 0.6))
	# The net he is not mending today lies heaped on the shingle west of him,
	# out of the way of the board.
	var x0 := SEAT.x - 0.9
	kit.quad("net", on_ground(x0, SEAT.y - 0.55), on_ground(x0 - 1.1, SEAT.y - 0.75),
			on_ground(x0 - 1.0, SEAT.y + 0.8), on_ground(x0, SEAT.y + 0.55))
	kit.quad("net", on_ground(x0 - 0.25, SEAT.y - 0.35, 0.06), on_ground(x0 - 0.85, SEAT.y - 0.45, 0.05),
			on_ground(x0 - 0.8, SEAT.y + 0.5, 0.05), on_ground(x0 - 0.2, SEAT.y + 0.35, 0.07))
	# the gutting board on a flat stone (boxes, no rng: the rocks after it stay put)
	var bg := ground(BOARD)
	kit.box("rock", Vector3(BOARD.x, bg + (BOARD_TOP - 0.05) / 2.0, BOARD.y), Vector3(0.4, BOARD_TOP - 0.05, 0.36), ["bottom"])
	kit.box("wood", Vector3(BOARD.x, bg + BOARD_TOP - 0.025, BOARD.y), Vector3(0.36, 0.05, 0.56), ["bottom"])
	# the flat basket for the gutted fish
	var gb := Vector3(GUTTED.x, ground(GUTTED), GUTTED.y)
	kit.lathe("basket", PackedVector2Array([Vector2(0.26, 0.0), Vector2(0.3, 0.12), Vector2(0.31, 0.14)]), 8, gb, 2.0, true, "basket")


func _baskets(kit: MeshKit, rng: RandomNumberGenerator) -> void:
	# Two baskets of the catch by the boat, and an upturned one by his side
	# (the sinkers lie on it).
	for p: Vector2 in CATCH:
		var c := Vector3(p.x, ground(p), p.y)
		kit.lathe("basket", PackedVector2Array([Vector2(0.24, 0.0), Vector2(0.3, 0.3), Vector2(0.32, 0.36)]), 8, c, 2.0,
				true, "basket")
		kit.add_collider(c + Vector3(0, 0.18, 0), Vector3(0.6, 0.36, 0.6))
		for i in 6:
			var f := c + Vector3(rng.randf_range(-0.15, 0.15), 0.33 + i * 0.012, rng.randf_range(-0.15, 0.15))
			kit.xform = Transform3D(Basis.from_euler(Vector3(0, rng.randf_range(0, TAU), 0)), f)
			kit.box("fish", Vector3.ZERO, Vector3(0.3, 0.05, 0.07), ["bottom"])
			kit.box("fish", Vector3(-0.17, 0, 0), Vector3(0.05, 0.04, 0.09), ["bottom"])  # tail
			kit.xform = Transform3D.IDENTITY
	var s := Vector3(SINKERS.x, ground(SINKERS), SINKERS.y)
	kit.lathe("basket", PackedVector2Array([Vector2(0.27, 0.0), Vector2(0.22, 0.34), Vector2(0.0, 0.36)]), 8, s, 2.0, true, "basket")
	kit.add_collider(s + Vector3(0, 0.17, 0), Vector3(0.5, 0.34, 0.5))


func _fire_ring(kit: MeshKit, rng: RandomNumberGenerator) -> void:
	var c := Vector3(FIRE.x, ground(FIRE), FIRE.y)
	for i in 7:
		var ang := TAU * i / 7.0
		kit.blob("rock", c + Vector3(cos(ang) * 0.42, 0.06, sin(ang) * 0.42), Vector3(0.12, 0.09, 0.1), 0.2, rng)
	for i in 3:
		kit.xform = Transform3D(Basis.from_euler(Vector3(0, TAU * i / 3.0, 0.25)), c + Vector3(0, 0.08, 0))
		kit.box("bark", Vector3.ZERO, Vector3(0.6, 0.07, 0.07), [])
	kit.xform = Transform3D.IDENTITY
	kit.quad("dark", on_ground(FIRE.x - 0.35, FIRE.y + 0.35, 0.02), on_ground(FIRE.x + 0.35, FIRE.y + 0.35, 0.02),
			on_ground(FIRE.x + 0.35, FIRE.y - 0.35, 0.02), on_ground(FIRE.x - 0.35, FIRE.y - 0.35, 0.02))


func _boat() -> void:
	# Stern to the land, bow down the shingle into the surf, keel along the slope,
	# heeled a little onto one side.
	var half := 2.3
	var hs := Topo.terrain(BOAT.x - half, BOAT.y)
	var hb := Topo.terrain(BOAT.x + half, BOAT.y)
	var pitch := atan2(hb - hs, half * 2.0)
	var basis := Basis(Vector3.UP, deg_to_rad(-8.0)) * Basis(Vector3.BACK, pitch) * Basis(Vector3.RIGHT, 0.06)
	var xf := Transform3D(basis, Vector3(BOAT.x, (hs + hb) / 2.0 - 0.04, BOAT.y))
	var model := Props.build("boat").build("Boat")
	model.transform = xf
	add_child(model)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(4.4, 0.7, 1.3)
	cs.shape = sh
	cs.transform = Transform3D(basis, xf * Vector3(0, 0.35, 0))
	props_body().add_child(cs)


func _fire() -> void:
	var c := Vector3(FIRE.x, ground(FIRE), FIRE.y)
	var flame := Lamp._make_flame(0.22)
	flame.position = c + Vector3(0, 0.12, 0)
	flame.emitting = true
	flame.visible = true
	add_child(flame)
	var glow := OmniLight3D.new()
	glow.position = c + Vector3(0, 0.5, 0)
	glow.light_color = Color(1, 0.55, 0.25)
	glow.omni_range = 5.0
	glow.set_script(preload("res://scripts/world/flicker.gd"))
	glow.base_energy = 0.8
	glow.amount = 0.35
	add_child(glow)


var _fisher: Npc
var _board_fish: MeshInstance3D
var _hand_fish: MeshInstance3D
var _gutted: Array[MeshInstance3D] = []


static func _fish_mesh() -> ArrayMesh:
	var kit := MeshKit.new()
	kit.box("fish", Vector3.ZERO, Vector3(0.3, 0.05, 0.07), [])
	kit.box("fish", Vector3(-0.17, 0, 0), Vector3(0.05, 0.04, 0.09), [])  # tail
	return kit.commit()


## His round as Npc patrol data, home at the stone.
static func set_fisher_round(f: Npc) -> void:
	var home := Vector3(FISHER_ROUTE[0][0], 0, FISHER_ROUTE[0][1])
	var pts := PackedVector3Array()
	var poses := PackedStringArray()
	var pauses := PackedFloat32Array()
	var faces := PackedFloat32Array()
	for r: Array in FISHER_ROUTE:
		pts.append(Vector3(r[0], 0, r[1]) - home)
		poses.append(r[2])
		pauses.append(r[3])
		faces.append(r[4])
	f.patrol = pts
	f.patrol_poses = poses
	f.patrol_pauses = pauses
	f.patrol_faces = faces
	f.patrol_speed = 0.5
	# he keeps at the work while watched; a talk holds the world anyway
	f.stops_for_player = false


func _fisherman() -> void:
	var f: Npc = NPC.new()
	f.npc_id = "fisher"
	f.name_key = "NPC_FISHER_NAME"
	f.dialogue = load("res://data/dialogues/fisher.dialogue") as DialogueResource
	f.pose = "gut"
	f.body_mat = "chiton_dark"
	f.position = Vector3(SEAT.x, ground(SEAT), SEAT.y)
	f.rotation.y = deg_to_rad(90.0)  # faces west, up the beach towards the city
	set_fisher_round(f)
	add_child(f)
	_fisher = f
	var mesh := _fish_mesh()
	# the knife in his right hand, the blade on past the fist
	var knife := MeshInstance3D.new()
	var kk := MeshKit.new()
	kk.box("bronze", Vector3(0, -0.36, 0.0), Vector3(0.02, 0.13, 0.008), [])
	kk.box("wood", Vector3(0, -0.28, 0.0), Vector3(0.03, 0.06, 0.03), [])
	knife.mesh = kk.commit()
	(f.joints["r_elbow"] as Node3D).add_child(knife)
	# the fish on the board, across it, head to his left
	_board_fish = MeshInstance3D.new()
	_board_fish.mesh = mesh
	_board_fish.position = Vector3(BOARD.x, ground(BOARD) + BOARD_TOP + 0.03, BOARD.y)
	_board_fish.rotation.y = deg_to_rad(90.0)
	add_child(_board_fish)
	# a fresh one by the gills, carried back from the basket, hanging from the hand
	_hand_fish = MeshInstance3D.new()
	_hand_fish.mesh = mesh
	_hand_fish.position = Vector3(0, -0.44, 0)
	_hand_fish.rotation.z = deg_to_rad(90.0)
	_hand_fish.visible = false
	(f.joints["l_elbow"] as Node3D).add_child(_hand_fish)
	# the gutted ones laid in the flat basket, side by side
	for i in GUTTED_MAX:
		var g := MeshInstance3D.new()
		g.mesh = mesh
		g.position = Vector3(GUTTED.x - 0.16 + i * 0.08, ground(GUTTED) + 0.09 + (i % 2) * 0.01, GUTTED.y)
		g.rotation.y = deg_to_rad(90.0 + (i % 3 - 1) * 8.0)
		g.visible = false
		add_child(g)
		_gutted.append(g)
	f.departed.connect(_on_fisher_departed)
	f.reached.connect(_on_fisher_reached)


func _on_fisher_departed(i: int) -> void:
	if i == FISHER_BOARD:
		# done with this one: into the basket with the others
		_board_fish.visible = false
		for g in _gutted:
			if not g.visible:
				g.visible = true
				break
	elif i == FISHER_CATCH:
		_hand_fish.visible = true


func _on_fisher_reached(i: int) -> void:
	if i == FISHER_BOARD:
		_hand_fish.visible = false
		_board_fish.visible = true


## How many gutted fish lie in the basket (for the tests).
func gutted_count() -> int:
	return _gutted.filter(func(g: MeshInstance3D) -> bool: return g.visible).size()


func fisher() -> Npc:
	return _fisher


## The rocks the cormorants stand on: their tops, on the beach's own height.
static func cormorant_rock_tops() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for r: Vector3 in CORMORANT_ROCKS:
		out.append(Vector3(r.x, Topo.terrain(r.x, r.z) + 0.42, r.z))
	return out


func _cormorant_rocks(kit: MeshKit, rng: RandomNumberGenerator) -> void:
	for top: Vector3 in cormorant_rock_tops():
		kit.blob("rock", top - Vector3(0, 0.3, 0), Vector3(0.8, 0.34, 0.65), 0.15, rng)


func _cormorants() -> void:
	var tops := cormorant_rock_tops()
	for i in tops.size():
		var b := Cormorant.new()
		b.name = "CormorantRock%d" % i
		b.home = tops[i]
		b.on_rock = true
		add_child(b)
	for i in CORMORANTS_ON_SAND:
		var b := Cormorant.new()
		b.name = "CormorantSand%d" % i
		b.home = Vector3(CORMORANT_SAND.x, Topo.terrain(CORMORANT_SAND.x, CORMORANT_SAND.y), CORMORANT_SAND.y)
		b.radius = CORMORANT_SAND_R
		add_child(b)
