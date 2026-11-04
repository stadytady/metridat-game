extends District
## The rest of the city as seen from the hill: terraces of simple houses on the
## slopes, batched into one mesh, and the city wall with towers on the ridges.
## Everything collides, but the walls also bound the play area north and south.

const WALL_Z := 78.0


func _ready() -> void:
	var kit := MeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var step := 9.0
	var x := -64.0
	while x < 60.0:
		var z := -72.0
		while z < 72.0:
			var px := x + rng.randf_range(-2.0, 2.0)
			var pz := z + rng.randf_range(-2.0, 2.0)
			z += step
			if absf(pz) < 12.0 or Topo.is_reserved(px, pz, 2.0) or rng.randf() < 0.18:
				continue
			if Topo.terrain(px, pz) < 2.2:
				continue  # keep the shore free
			_house(kit, rng, px, pz)
		x += step
	_walls(kit)
	add_child(kit.build("Backdrop"))


func _house(kit: MeshKit, rng: RandomNumberGenerator, px: float, pz: float) -> void:
	var w := rng.randf_range(5.0, 8.0)
	var d := rng.randf_range(4.5, 7.0)
	# face downhill (east) or towards the street axis, with a little jitter
	var yaw := (PI / 2.0 if rng.randf() < 0.5 else (0.0 if pz < 0 else PI)) + rng.randf_range(-0.12, 0.12)
	var basis := Basis.from_euler(Vector3(0, yaw, 0))
	var center := Vector3(px, 0, pz)
	var lo := INF
	var hi := -INF
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			var q := center + basis * Vector3(sx * w, 0, sz * d)
			var t := Topo.terrain(q.x, q.z)
			lo = minf(lo, t)
			hi = maxf(hi, t)
	var front := center + basis * Vector3(0, 0, d / 2.0)
	front.y = hi
	var h := rng.randf_range(3.0, 4.3)  # drawn before the options, as it always was
	var opts := {
		"drop": hi - lo + 1.0,
		"roof": "gable" if rng.randf() < 0.65 else "flat",
		"door": rng.randf() < 0.6,
		"windows": rng.randi_range(0, 1),
	}
	# the walk-in house stands here: draw the same numbers, build nothing, so
	# the rest of the city keeps its place
	if Topo.in_house(px, pz, 6.0):
		return
	Arch.house(kit, Transform3D(basis, front), w, d, h, opts)


func _walls(kit: MeshKit) -> void:
	for side: float in [1.0, -1.0]:
		var x := -110.0
		var seg := 0
		while x < 62.0:
			var x2 := x + 10.0
			var a := Vector3(x, Topo.terrain(x, side * WALL_Z), side * WALL_Z)
			var b := Vector3(x2, Topo.terrain(x2, side * WALL_Z), side * WALL_Z)
			var base := minf(a.y, b.y) - 1.5
			var top := maxf(a.y, b.y) + 4.0
			kit.solid_box("limestone", Vector3((x + x2) / 2.0, (base + top) / 2.0, side * WALL_Z), Vector3(10.2, top - base, 1.8), ["bottom"])
			if seg % 4 == 0:
				var tb := a.y - 1.5
				kit.solid_box("limestone", Vector3(x, tb + 3.6, side * WALL_Z), Vector3(6.0, 7.2, 6.0), ["bottom"])
				kit.box("roof", Vector3(x, tb + 7.3, side * WALL_Z), Vector3(6.4, 0.25, 6.4), ["bottom"])
			x = x2
			seg += 1
