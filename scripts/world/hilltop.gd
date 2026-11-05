extends District
## Starting point: a paved lookout terrace on the summit with a broken parapet,
## fallen architecture, and two standing columns framing the way down. The
## west half holds a small theatre (theatre.gd). Gates in the north and south
## parapets open onto the park (park.gd).

const PARK := preload("res://scripts/world/park.gd")


func _ready() -> void:
	var kit := MeshKit.new()
	var c := Topo.HILL_CENTER
	var h := Topo.HILL_HALF
	var top := Topo.HILL_PLATFORM_TOP
	Arch.platform(kit, c, h, top, Topo.HILL_H - 2.5, "paving")
	# steps down to the street
	Arch.path(kit, [Vector3(c.x + h.x - 0.2, top, 0), Vector3(Topo.STREET[0].x, Topo.STREET[0].y, Topo.STREET[0].z)] as Array[Vector3], 2.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var x0 := c.x - h.x + 0.3
	var x1 := c.x + h.x - 0.3
	# Parapet with gaps; the east side stays open towards the city. Two gates are
	# left for the park walks, which leave the terrace north and south: any
	# segment that would close the opening is dropped, the rng is not, so the rest
	# of the parapet stays exactly as it was.
	for z: float in [c.y - h.y + 0.3, c.y + h.y - 0.3]:
		var x := x0
		var gap_lo := INF
		var gap_hi := -INF
		while x < x1:
			var seg := rng.randf_range(2.0, 4.0)
			var hh := rng.randf_range(0.35, 0.9)
			var a := x
			var b := minf(x + seg, x1)
			if absf((a + b) * 0.5 - PARK.GATE_X) <= (b - a) * 0.5 + PARK.CROSS_HALF:
				gap_lo = minf(gap_lo, a)
				gap_hi = maxf(gap_hi, b)
			else:
				kit.solid_box("limestone", Vector3((a + b) / 2.0, top + hh / 2.0, z), Vector3(b - a, hh, 0.55), ["bottom"])
			x += seg + rng.randf_range(0.5, 1.6)
		# Gate posts at the edges of the opening that was left.
		if gap_lo < gap_hi:
			for gx: float in [gap_lo + 0.25, gap_hi - 0.25]:
				kit.solid_box("limestone", Vector3(gx, top + 0.45, z), Vector3(0.5, 0.9, 0.62), ["bottom"])
	# Three steps down through each gate: the ground outside the platform sits
	# about a metre below it, too much to step over and too steep to ramp.
	for sz: float in [-1.0, 1.0]:
		for i in 3:
			kit.solid_box("limestone", Vector3(PARK.GATE_X, top - 0.3 * (i + 1) + 0.15, sz * (h.y - 0.1 + i * 0.42 + 0.21)),
					Vector3(PARK.CROSS_HALF * 2.0, 0.3, 0.42), ["bottom"])
	var zz := c.y - h.y + 0.6
	while zz < c.y + h.y - 0.6:
		var seg := rng.randf_range(2.0, 3.5)
		kit.solid_box("limestone", Vector3(x0, top + 0.35, minf(zz + seg / 2.0, c.y + h.y - 0.6)), Vector3(0.55, 0.7, seg), ["bottom"])
		zz += seg + rng.randf_range(0.6, 1.4)
	for sz: float in [-1.0, 1.0]:
		kit.solid_box("limestone", Vector3(x1, top + 0.4, sz * 5.5), Vector3(0.55, 0.8, 4.0), ["bottom"])
	# fallen drums and blocks
	Arch.drum(kit, Arch.frame(Vector3(c.x - 3, top, -4.5), Vector3(1, 0, 0.4)), 0.3, 1.1)
	Arch.drum(kit, Arch.frame(Vector3(c.x + 2.5, top, 5.2), Vector3(0.3, 0, 1)), 0.3, 0.9)
	for b: Array in [[Vector3(c.x + 4, top, -5.6), 0.5], [Vector3(c.x + 3.0, top, -6.2), 0.4], [Vector3(c.x - 6.5, top, -5.0), 0.6]]:
		kit.xform = Transform3D(Basis.from_euler(Vector3(0, rng.randf_range(-0.5, 0.5), 0)), b[0])
		kit.solid_box("limestone", Vector3(0, b[1] / 2.0, 0), Vector3(1.0, b[1], 0.7), ["bottom"])
	kit.xform = Transform3D.IDENTITY
	add_child(kit.build("Terrace"))
	# two standing columns frame the view and the steps down to the city
	for sz: float in [-1.0, 1.0]:
		place("column_doric", Vector3(x1 - 0.6, top, sz * 3.1), 0.0, Vector3.ONE, 0.32, 3.6)
	_olives()
	spawn_inspectable("sherd_kerch", Vector3(c.x + 3.0, top + 0.4, -6.2), 20.0)


## Olive bushes round the terrace: low and wide, on the slopes outside the
## parapet and one in the corner by the view. Clear of the steps down (east).
const OLIVES := [
	Vector2(-95.5, 10.2), Vector2(-88.0, 10.8), Vector2(-82.5, 9.6), Vector2(-101.2, 4.5),
	Vector2(-101.6, -3.8), Vector2(-96.0, -10.4), Vector2(-89.5, -10.9), Vector2(-83.0, -9.8),
	Vector2(-83.4, 6.4),
]


func _olives() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 314
	for p: Vector2 in OLIVES:
		var y := Topo.surface(p.x, p.y) - (0.0 if Topo.in_rect(p.x, p.y, Topo.HILL_CENTER, Topo.HILL_HALF - Vector2(1, 1)) else 0.15)
		var s := rng.randf_range(0.5, 0.7)
		place("olive_tree", Vector3(p.x, y, p.y), rng.randf_range(0, 360), Vector3(s * 1.3, s * 0.75, s * 1.3))
