extends District
## Starting point: a paved lookout terrace on the summit with a broken parapet,
## fallen architecture, and two standing columns framing the way down. The
## west half holds a small theatre (theatre.gd).


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
	# parapet with gaps; the east side stays open towards the city
	var x0 := c.x - h.x + 0.3
	var x1 := c.x + h.x - 0.3
	for z: float in [c.y - h.y + 0.3, c.y + h.y - 0.3]:
		var x := x0
		while x < x1:
			var seg := rng.randf_range(2.0, 4.0)
			var hh := rng.randf_range(0.35, 0.9)
			kit.solid_box("limestone", Vector3(minf(x + seg / 2.0, x1), top + hh / 2.0, z), Vector3(minf(seg, x1 - x), hh, 0.55), ["bottom"])
			x += seg + rng.randf_range(0.5, 1.6)
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
	spawn_inspectable("sherd_kerch", Vector3(c.x + 3.0, top + 0.4, -6.2), 20.0)
