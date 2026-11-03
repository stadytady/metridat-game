extends District
## Terrace sanctuary above the agora: small temple in antis, an altar with a
## fire (the focal point at dusk), a bronze tripod, votive ledge, cypresses.

const COL_H := 3.0


func _ready() -> void:
	var c := Topo.SANCT_CENTER
	var h := Topo.SANCT_HALF
	var y := Topo.SANCT_H
	var kit := MeshKit.new()
	Arch.platform(kit, c, h, y, District.min_terrain(c, h) - 1.0)
	Arch.path(kit, Topo.SANCT_STAIR, Topo.SANCT_STAIR_HALF)
	# landing at the bottom of the stair, inside the agora's corner
	var temple_xf := Arch.frame(Vector3(c.x, y, -27.0), Vector3.RIGHT)
	var cols := Arch.naiskos(kit, temple_xf, 5.2, 6.5, COL_H)
	var altar_pos := Vector3(c.x, y, -23.2)
	Arch.altar(kit, Arch.frame(altar_pos, Vector3.RIGHT))
	# low temenos wall; a gap at the south-west where the stair arrives
	var x0 := c.x - h.x + 0.25
	var x1 := c.x + h.x - 0.25
	var z0 := c.y - h.y + 0.25
	var z1 := c.y + h.y - 0.25
	var wall := 1.1
	kit.solid_box("limestone", Vector3(c.x, y + wall / 2.0, z0), Vector3(h.x * 2, wall, 0.5), ["bottom"])
	kit.solid_box("limestone", Vector3(x1, y + wall / 2.0, c.y), Vector3(0.5, wall, h.y * 2), ["bottom"])
	kit.solid_box("limestone", Vector3(x0, y + wall / 2.0, c.y - 1.5), Vector3(0.5, wall, h.y * 2 - 3.0), ["bottom"])
	var gap_end := Topo.SANCT_STAIR[1].x + Topo.SANCT_STAIR_HALF + 0.3
	kit.solid_box("limestone", Vector3((gap_end + x1) / 2.0, y + wall / 2.0, z1), Vector3(x1 - gap_end, wall, 0.5), ["bottom"])
	# votive ledge along the east wall
	kit.solid_box("limestone", Vector3(x1 - 0.7, y + 0.45, c.y - 2.0), Vector3(0.9, 0.9, 6.0), ["bottom"])
	_sacred_way(kit)
	add_child(kit.build("Sanctuary"))
	for p: Vector3 in cols:
		place("column_doric", temple_xf * p, 0.0, Vector3(1, COL_H / 3.6, 1), 0.3, COL_H)
	place("tripod", altar_pos + Vector3(2.4, 0, 0.6), 20.0, Vector3.ONE, 0.4, 1.4)
	place("cypress", Vector3(x0 + 1.2, y, z0 + 1.2), 0.0, Vector3.ONE, 0.2, 2.0)
	place("cypress", Vector3(x1 - 1.4, y, z0 + 1.2), 40.0, Vector3.ONE * 1.1, 0.2, 2.0)
	var ledge_top := y + 0.9
	for i in 5:
		if i == 2:
			continue
		place("figurine", Vector3(x1 - 0.7, ledge_top, c.y - 4.2 + i * 1.0), -90.0 + i * 7.0, Vector3.ONE * (0.9 + 0.1 * (i % 2)))
	place("krater", Vector3(x1 - 0.7, ledge_top, c.y + 0.6), 0.0, Vector3.ONE * 0.45)
	spawn_inspectable("votive_figurine", Vector3(x1 - 0.7, ledge_top, c.y - 2.2), -90.0)
	var fire: Node3D = preload("res://scenes/environment/altar_fire.tscn").instantiate()
	fire.position = altar_pos + Vector3(0, 1.1, 0)
	add_child(fire)


## The way up from the agora must read from across the square: a gateway at
## the foot of the stair (pillars, a lintel with a painted band and a garland)
## and cypresses lining the climb. Pillars stand clear of the stair, the
## stoa's corner and the torches.
func _sacred_way(kit: MeshKit) -> void:
	var s0 := Topo.SANCT_STAIR[0]
	var s1 := Topo.SANCT_STAIR[1]
	var dir := Vector3(s1.x - s0.x, 0, s1.z - s0.z).normalized()
	var gate := s0 + dir * 0.6
	gate.y = _stair_y(0.6 / Vector2(s1.x - s0.x, s1.z - s0.z).length())
	var xf := Arch.frame(gate, dir)
	var top := 3.3
	for side: float in [-1.0, 1.0]:
		var local := Vector3(0, 0, side * 2.0)
		var w := xf * local
		var ground := Topo.surface(w.x, w.z)
		var h := gate.y + top - ground
		kit.xform = xf
		kit.solid_box("limestone", local + Vector3(0, ground - gate.y + h / 2.0, 0), Vector3(0.5, h, 0.5), ["bottom"])
		kit.box("limestone", local + Vector3(0, top - 0.1, 0), Vector3(0.62, 0.2, 0.62), [])
	kit.xform = xf
	kit.box("limestone", Vector3(0, top + 0.18, 0), Vector3(0.55, 0.36, 4.7), [])
	kit.box("redfigure", Vector3(-0.28, top + 0.18, 0), Vector3(0.01, 0.2, 4.4), ["bottom", "top"])
	kit.box("redfigure", Vector3(0.28, top + 0.18, 0), Vector3(0.01, 0.2, 4.4), ["bottom", "top"])
	# garland: a sagging rope of leaves between the pillars, seen from the agora
	var prev := Vector3(-0.3, top - 0.05, -1.75)
	for i in range(1, 7):
		var t := i / 6.0
		var p := Vector3(-0.3, top - 0.05 - sin(t * PI) * 0.55, lerpf(-1.75, 1.75, t))
		kit.xform = xf * Props.align_y(prev, p)
		kit.box("foliage", Vector3(0, prev.distance_to(p) / 2.0, 0), Vector3(0.12, prev.distance_to(p) + 0.04, 0.12), [])
		prev = p
	kit.xform = Transform3D.IDENTITY
	# cypresses along both sides of the climb
	var perp := Vector3(-dir.z, 0, dir.x)
	for t: float in [0.3, 0.6, 0.9]:
		for side: float in [-1.0, 1.0]:
			var q := s0.lerp(s1, t) + perp * side * 3.1
			place("cypress", Vector3(q.x, Topo.terrain(q.x, q.z) - 0.1, q.z), t * 90.0, Vector3.ONE * (1.25 + 0.1 * side * t), 0.2, 2.0)


## Height of the stair axis at fraction u from the foot.
static func _stair_y(u: float) -> float:
	return lerpf(Topo.SANCT_STAIR[0].y, Topo.SANCT_STAIR[1].y, clampf(u, 0.0, 1.0))
