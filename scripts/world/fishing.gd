extends District
## Fisherman's camp on the beach below the agora: a small boat hauled up the
## shingle, a net drying on two poles, baskets of the morning catch, a stone
## to sit on and a driftwood fire. Glaukos mends a net across his knees.

const NPC := preload("res://scripts/npc/npc.gd")

const SEAT := Vector2(65.6, 14.6)
const BOAT := Vector2(69.6, 16.4)
const RACK := [Vector2(63.6, 11.0), Vector2(66.6, 11.0)]
const FIRE := Vector2(64.4, 17.0)
const SINKERS := Vector2(65.7, 13.6)
## Cormorants on the beach some fifty metres south of the Swallow, above the
## surf: a patch of sand they walk, and two rocks they dry their wings on.
## Glaukos's errand: a hook dropped at the foot of the drying net, on this side
## of it (the net is solid to the ray).
const LOST_HOOK := Vector2(65.1, 11.4)
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


func _rack(kit: MeshKit) -> void:
	var top := 1.85
	var a: Vector2 = RACK[0]
	var b: Vector2 = RACK[1]
	var ya := ground(a)
	var yb := ground(b)
	for p: Vector2 in RACK:
		kit.solid_box("wood", Vector3(p.x, ground(p) + top / 2.0, p.y), Vector3(0.1, top + 0.2, 0.1), ["bottom"])
	var bar_y := (ya + yb) / 2.0 + top - 0.08
	kit.box("wood", Vector3((a.x + b.x) / 2.0, bar_y, a.y), Vector3(b.x - a.x + 0.3, 0.07, 0.07), [])
	# The net hangs over the bar and sags in the middle; cut-out, seen from both sides.
	var mid := (a.x + b.x) / 2.0
	var low := 0.35
	var pts := [Vector3(a.x + 0.05, ya + low + 0.15, a.y), Vector3(mid, (ya + yb) / 2.0 + low, a.y),
		Vector3(b.x - 0.05, yb + low + 0.15, a.y)]
	for i in 2:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		kit.quad("net", p0, p1, Vector3(p1.x, bar_y, a.y), Vector3(p0.x, bar_y, a.y))
	kit.add_collider(Vector3(mid, bar_y - 0.6, a.y), Vector3(b.x - a.x, 1.2, 0.1))


func _seat_and_nets(kit: MeshKit, rng: RandomNumberGenerator) -> void:
	var g := ground(SEAT)
	kit.blob("rock", Vector3(SEAT.x + 0.05, g + 0.16, SEAT.y), Vector3(0.32, 0.26, 0.3), 0.15, rng)
	kit.add_collider(Vector3(SEAT.x, g + 0.2, SEAT.y), Vector3(0.6, 0.4, 0.6))
	# The net over his knees runs west, down to the shingle, and lies there in folds.
	var kx := SEAT.x - 0.55
	var knee := g + 0.5
	for z0: float in [-0.45, 0.0]:
		var z1 := z0 + 0.45
		kit.quad("net", Vector3(SEAT.x - 0.15, g + 0.42, SEAT.y + z0), Vector3(kx, knee, SEAT.y + z0),
				Vector3(kx, knee, SEAT.y + z1), Vector3(SEAT.x - 0.15, g + 0.42, SEAT.y + z1))
		kit.quad("net", Vector3(kx, knee, SEAT.y + z0), on_ground(kx - 0.35, SEAT.y + z0 - 0.1),
				on_ground(kx - 0.35, SEAT.y + z1 + 0.1), Vector3(kx, knee, SEAT.y + z1))
	var x0 := kx - 0.35
	kit.quad("net", on_ground(x0, SEAT.y - 0.55), on_ground(x0 - 1.1, SEAT.y - 0.75),
			on_ground(x0 - 1.0, SEAT.y + 0.8), on_ground(x0, SEAT.y + 0.55))


func _baskets(kit: MeshKit, rng: RandomNumberGenerator) -> void:
	# Two baskets of the catch by the boat, and an upturned one by his side
	# (the sinkers lie on it).
	for p: Vector2 in [Vector2(67.4, 13.2), Vector2(67.9, 14.0)]:
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


func _fisherman() -> void:
	var f: Npc = NPC.new()
	f.npc_id = "fisher"
	f.name_key = "NPC_FISHER_NAME"
	f.dialogue = load("res://data/dialogues/fisher.dialogue") as DialogueResource
	f.pose = "mender"
	f.body_mat = "chiton_dark"
	f.position = Vector3(SEAT.x, ground(SEAT), SEAT.y)
	f.rotation.y = deg_to_rad(90.0)  # faces west, up the beach towards the city
	add_child(f)


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
