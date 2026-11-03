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
