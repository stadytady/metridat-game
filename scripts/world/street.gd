extends District
## The stepped street from the hill down to the agora: paving and stairs,
## houses on both sides following the street, walled courtyards with storage
## jars. The first courtyard on the south side holds the stamped amphora.

const START_X := -64.0
const END_X := 3.0

var courtyards: Array[Transform3D] = []
var _glow: Node3D
var _glow_kit := MeshKit.new()
var _atm: Node


func _ready() -> void:
	var kit := MeshKit.new()
	Arch.path(kit, Topo.STREET, Topo.STREET_HALF)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for side: float in [1.0, -1.0]:
		_build_side(kit, rng, side)
	add_child(kit.build("Street"))
	_glow = _glow_kit.build("WindowGlow")
	add_child(_glow)
	_atm = get_parent().get_node_or_null("Atmosphere")
	_furnish(rng)


func _street_dir(x: float) -> Vector3:
	var dz := (Topo.street_z(x + 0.5) - Topo.street_z(x - 0.5))
	return Vector3(1, 0, dz).normalized()


func _build_side(kit: MeshKit, rng: RandomNumberGenerator, side: float) -> void:
	var x := START_X + (0.0 if side > 0 else 2.5)
	var slot := 0
	while x < END_X:
		var steep := absf(Topo.street_height(x + 3) - Topo.street_height(x - 3)) > 2.0
		var courtyard := slot % 4 == 2
		var w := rng.randf_range(6.0, 7.0) if courtyard else (rng.randf_range(4.2, 5.4) if steep else rng.randf_range(5.0, 7.5))
		var cx := x + w / 2.0
		if cx + w / 2.0 > END_X:
			break
		var dir := _street_dir(cx)
		var out := Vector3(-dir.z, 0, dir.x) * side  # away from the street
		var floor_y := Topo.street_height(cx)
		var front := Vector3(cx, floor_y, Topo.street_z(cx)) + out * (Topo.STREET_HALF + 0.2)
		# local +z must face the street, i.e. -out
		var z_axis := -out
		var x_axis := Vector3.UP.cross(z_axis)
		var xf := Transform3D(Basis(x_axis, Vector3.UP, z_axis), front)
		var d := rng.randf_range(5.0, 7.0)
		var lowest := floor_y
		for k in [-0.5, 0.5]:
			lowest = minf(lowest, Topo.street_height(cx + k * w))
			lowest = minf(lowest, Topo.terrain(front.x + dir.x * k * w + out.x * d, front.z + dir.z * k * w + out.z * d))
		var drop := floor_y - lowest + 1.2
		if courtyard:
			Arch.courtyard(kit, xf, w, d, 2.4, drop)
			courtyards.append(xf)
		else:
			Arch.house(kit, xf, w, d, rng.randf_range(3.3, 4.6), {
				"drop": drop,
				"roof": "gable" if rng.randf() < 0.72 else "flat",
				"door": rng.randf() < 0.85,
				"door_x": rng.randf_range(-w / 2.0 + 1.0, w / 2.0 - 1.0),
				# a few slipped tiles on some roofs; seeded by the house's place, not the
				# street's rng, so nothing else on the street moves
				"missing_tiles": 2 if int(absf(cx) * 7.0) % 3 == 0 else 0,
				"seed": int(cx * 100.0),
				"windows": rng.randi_range(0, 2),
				"glow": _glow_kit,  # lamps in some windows after dusk
			})
		x += w + (rng.randf_range(0.0, 1.4) if rng.randf() < 0.35 else 0.0)
		slot += 1


## Storage jars, amphorae and a tree in each courtyard; jars along house walls.
func _furnish(rng: RandomNumberGenerator) -> void:
	var first := true
	for xf in courtyards:
		var p := func(local: Vector3) -> Vector3:
			return xf * local
		place("pithos", p.call(Vector3(-1.8, 0, -3.8)), rng.randf_range(0, 360), Vector3.ONE, 0.5, 1.3)
		place("pithos", p.call(Vector3(-0.8, 0, -4.4)), rng.randf_range(0, 360), Vector3.ONE * 0.85, 0.42, 1.1)
		for i in 3:
			place("amphora", p.call(Vector3(1.4 + i * 0.32, 0, -4.6 + i * 0.1)), rng.randf_range(0, 360))
		place("olive_tree", p.call(Vector3(1.6, 0, -2.0)), rng.randf_range(0, 360), Vector3.ONE * 0.8, 0.18, 2.0)
		if first:
			# local yaw: face the gate
			var yaw := rad_to_deg(xf.basis.get_euler().y)
			spawn_inspectable("amphora_stamped", p.call(Vector3(-0.3, 0, -2.6)), yaw)
			first = false
	# loose amphorae leaning by doorways along the street
	for i in 10:
		var x := rng.randf_range(START_X + 4, END_X - 4)
		var side := 1.0 if i % 2 == 0 else -1.0
		var dir := _street_dir(x)
		var out := Vector3(-dir.z, 0, dir.x) * side
		var pos := Vector3(x, Topo.street_height(x), Topo.street_z(x)) + out * (Topo.STREET_HALF - 0.25)
		place("amphora", pos, rng.randf_range(0, 360), Vector3.ONE, 0.17, 0.8)


func _process(_delta: float) -> void:
	_glow.visible = _atm != null and _atm.t >= 0.75
