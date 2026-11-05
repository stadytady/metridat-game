extends District
## A small theatre on the summit terrace: three low tiers of stone seats in a
## half-ring round a marked orchestra, looking east over the city to the
## strait, and a wooden stand by the orchestra hung with masks, tragic and
## comic. The tiers rise less than a step, so you can climb them and sit.

const CENTER := Vector2(-91.5, 0.0)
const INNER_R := 3.4
const TIER_DEPTH := 0.75
const TIER_RISE := 0.28
const TIERS := 3
## The seats wrap the west side: angles (deg) in the x-z plane from +x.
const ARC_FROM := 120.0
const ARC_TO := 240.0
const ARC_STEP := 10.0
const ORCHESTRA_R := 3.0
const STAND := Vector2(-88.6, 3.9)
## The actor rehearses in the orchestra, facing the empty seats.
const ACTOR := Vector2(-90.6, 0.3)
const NPC := preload("res://scripts/npc/npc.gd")
## Two lamps of the hill lit within this radius and fire answers at the corners.
const FIRE_RADIUS := 12.0

var _fires: Array[CornerFire] = []
var _fires_lit := false


## Every seat block: [centre on the floor, yaw (rad), size].
static func seat_blocks() -> Array:
	var out := []
	var top := Topo.HILL_PLATFORM_TOP
	for i in TIERS:
		var r0 := INNER_R + i * TIER_DEPTH
		var r1 := r0 + TIER_DEPTH
		var h := (i + 1) * TIER_RISE
		var a := ARC_FROM + ARC_STEP / 2.0
		while a < ARC_TO:
			var rad := deg_to_rad(a)
			var rm := (r0 + r1) / 2.0
			var chord := 2.0 * r1 * sin(deg_to_rad(ARC_STEP) / 2.0) + 0.04  # overlap: no slits
			out.append([Vector3(CENTER.x + cos(rad) * rm, top, CENTER.y + sin(rad) * rm), -rad, Vector3(TIER_DEPTH, h, chord)])
			a += ARC_STEP
	return out


## The stand faces the start of the walk, so its masks greet you when you turn round.
static func stand_yaw() -> float:
	var d := Topo.spawn_point() - Vector3(STAND.x, 0, STAND.y)
	return atan2(-d.x, -d.z)


func _ready() -> void:
	var kit := MeshKit.new()
	for b: Array in seat_blocks():
		var size: Vector3 = b[2]
		kit.xform = Transform3D(Basis(Vector3.UP, b[1]), b[0])
		kit.solid_box("limestone", Vector3(0, size.y / 2.0, 0), size, ["bottom"])
	kit.xform = Transform3D.IDENTITY
	_orchestra(kit)
	_stand(kit)
	add_child(kit.build("Theatre"))
	_actor()
	_braziers()
	Game.lamp_lit.connect(_on_lamp_lit)
	_sync_braziers()


## Four torches: the two ends of the seat ring and the two front corners of the
## orchestra, where the audience would have come in.
func _braziers() -> void:
	var top := Topo.HILL_PLATFORM_TOP
	var ring := INNER_R + TIERS * TIER_DEPTH + 0.5
	for a: float in [ARC_FROM, ARC_TO]:
		var rad := deg_to_rad(a)
		_add_fire(Vector3(CENTER.x + cos(rad) * ring, top, CENTER.y + sin(rad) * ring))
	for a: float in [-32.0, 32.0]:
		var rad := deg_to_rad(a)
		var r := ORCHESTRA_R + 0.55
		_add_fire(Vector3(CENTER.x + cos(rad) * r, top, CENTER.y + sin(rad) * r))


func _add_fire(pos: Vector3) -> void:
	var f := CornerFire.new()
	f.position = pos
	add_child(f)
	f.add_to_group(&"corner_fire")
	_fires.append(f)


func _on_lamp_lit(_lit: int, _total: int) -> void:
	_sync_braziers()


## The theatre answers the player rather than a script: light both lamps that
## stand by the orchestra and the corners take fire; let them be and it stays
## dark. Cheap enough to recount on every lamp that goes up.
func _sync_braziers() -> void:
	if _fires.is_empty():
		return
	var near := 0
	for l: Lamp in Game.lamps:
		if l.lit and Vector2(l.global_position.x - CENTER.x, l.global_position.z - CENTER.y).length() <= FIRE_RADIUS:
			near += 1
	var want := near >= 2
	if want == _fires_lit:
		return
	_fires_lit = want
	for f in _fires:
		f.set_lit(want)


## A ring of pale slabs flush with the paving marks the orchestra.
func _orchestra(kit: MeshKit) -> void:
	var y := Topo.HILL_PLATFORM_TOP + 0.012
	var n := 24
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p := func(r: float, a: float) -> Vector3:
			return Vector3(CENTER.x + cos(a) * r, y, CENTER.y + sin(a) * r)
		kit.quad("column", p.call(ORCHESTRA_R + 0.25, a0), p.call(ORCHESTRA_R, a0), p.call(ORCHESTRA_R, a1), p.call(ORCHESTRA_R + 0.25, a1))


func _stand(kit: MeshKit) -> void:
	var at := Vector3(STAND.x, Topo.HILL_PLATFORM_TOP, STAND.y)
	kit.xform = Transform3D(Basis(Vector3.UP, stand_yaw()), at)
	for sx: float in [-0.7, 0.7]:
		kit.box("wood", Vector3(sx, 0.85, 0), Vector3(0.08, 1.7, 0.08), ["bottom"])
	kit.box("wood", Vector3(0, 1.62, 0), Vector3(1.5, 0.06, 0.06), [])
	kit.box("wood", Vector3(0, 0.98, 0), Vector3(1.5, 0.05, 0.05), [])
	kit.add_collider(Vector3(0, 0.85, 0), Vector3(1.5, 1.7, 0.2))
	# four masks, two tragic and two comic, on pegs below the bars
	_mask(kit, Vector3(-0.35, 1.36, -0.07), true, "mask", true)
	_mask(kit, Vector3(0.35, 1.36, -0.07), false, "mask_ochre", true)
	_mask(kit, Vector3(-0.35, 0.73, -0.06), false, "mask", false)
	_mask(kit, Vector3(0.35, 0.73, -0.06), true, "mask_ochre", false)
	kit.xform = Transform3D.IDENTITY


## A mask facing -Z: face plate, brow, nose, dark eye holes and a mouth that
## turns down (tragic) or grins (comic); bearded masks get hair and a beard.
func _mask(kit: MeshKit, c: Vector3, tragic: bool, mat: String, bearded: bool) -> void:
	kit.box(mat, c, Vector3(0.26, 0.34, 0.05), [])
	kit.box(mat, c + Vector3(0, 0.08, -0.035), Vector3(0.27, 0.045, 0.03), [])  # brow
	kit.box(mat, c + Vector3(0, 0.005, -0.045), Vector3(0.05, 0.09, 0.04), [])  # nose
	for s: float in [-1.0, 1.0]:
		kit.box("dark", c + Vector3(0.065 * s, 0.045 if tragic else 0.04, -0.028), Vector3(0.07, 0.045, 0.012), [])
	if tragic:
		kit.box("dark", c + Vector3(0, -0.085, -0.028), Vector3(0.11, 0.07, 0.012), [])  # open, wailing
		for s: float in [-1.0, 1.0]:
			kit.box("dark", c + Vector3(0.06 * s, -0.11, -0.028), Vector3(0.04, 0.035, 0.012), [])  # corners pulled down
	else:
		kit.box("dark", c + Vector3(0, -0.09, -0.028), Vector3(0.16, 0.06, 0.012), [])  # open, laughing
		for s: float in [-1.0, 1.0]:
			kit.box("dark", c + Vector3(0.085 * s, -0.065, -0.028), Vector3(0.04, 0.035, 0.012), [])  # corners pulled up
	if bearded:
		kit.box("hair", c + Vector3(0, 0.185, 0.005), Vector3(0.3, 0.06, 0.06), [])
		kit.box("hair", c + Vector3(0, -0.2, -0.005), Vector3(0.18, 0.08, 0.04), [])
	kit.box("wood", c + Vector3(0, 0.2 if not bearded else 0.24, 0.03), Vector3(0.025, 0.06, 0.025), [])  # peg


func _actor() -> void:
	var a: Npc = NPC.new()
	a.npc_id = "actor"
	a.name_key = "NPC_ACTOR_NAME"
	a.dialogue = load("res://data/dialogues/fedr.dialogue") as DialogueResource
	a.dialogue_start = "start"
	a.pose = "declaim"
	a.body_mat = "chiton"
	a.position = Vector3(ACTOR.x, Topo.HILL_PLATFORM_TOP, ACTOR.y)
	a.rotation.y = deg_to_rad(90.0)  # faces -x, the seats
	# Rehearsing is not standing still: he paces the orchestra, stops to think,
	# then stops to declaim, and breaks off to face whoever comes up to him.
	a.patrol = PackedVector3Array([Vector3(-0.9, 0, -0.9), Vector3(1.5, 0, -0.2), Vector3(0.3, 0, 1.4)])
	a.patrol_poses = PackedStringArray(["think", "declaim", "think"])
	a.patrol_speed = 0.5
	a.patrol_pause = 3.2
	add_child(a)
	# a mask in the left hand, face out
	var k := MeshKit.new()
	k.box("mask", Vector3(0, -0.36, -0.08), Vector3(0.2, 0.26, 0.04), [])
	k.box("dark", Vector3(-0.05, -0.32, -0.102), Vector3(0.05, 0.03, 0.01), [])
	k.box("dark", Vector3(0.05, -0.32, -0.102), Vector3(0.05, 0.03, 0.01), [])
	k.box("dark", Vector3(0, -0.42, -0.102), Vector3(0.09, 0.05, 0.01), [])
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	(a.joints["l_elbow"] as Node3D).add_child(mi)
